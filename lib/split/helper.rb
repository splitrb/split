module Split
  module Helper
    def batch_ab_test(metric_descriptor, split_ids, check_winner = true)
      begin
        experiment_name_with_version, goals = normalize_experiment(metric_descriptor)
        experiment_name = experiment_name_with_version.to_s.split(':')[0]
        experiment = Split::Experiment.new(experiment_name)
        control ||= experiment.control && experiment.control.name
        
        # this transformation from array to hash isn't too bad in terms of efficiency
        ret = Hash[split_ids.collect{|split_id| [split_id, nil]}]
        if Split.configuration.enabled
          experiment.save

          predetermined_alternative = predetermined_alternative(experiment)

          if predetermined_alternative
            ret.each {|k,v| ret[k] = predetermined_alternative}
          else
            # preload participating? states for all split_ids
            Split::Experiment.preload_participating!(experiment, split_ids)

            trial = Trial.new(:experiment => experiment, :users => split_ids)
            alternatives = trial.choose!
            call_trial_choose_hook(trial)

            ret = alternatives.update(alternatives){|user, alternative| alternative.name}
          end
        else
          control_name = control_variable(control)
          ret.select{|k,v| v.nil?}.each{|k,v| ret[k] = control_name}
        end
      rescue Errno::ECONNREFUSED => e
        raise(e) unless Split.configuration.db_failover
        Split.configuration.db_failover_on_db_error.call(e)
      ensure
        ret ||= Hash[split_ids.collect{|split_id| [split_id, nil]}]
      end
    end
    
    def ab_test(metric_descriptor, control=nil, *alternatives)
      if RUBY_VERSION.match(/1\.8/) && alternatives.length.zero? && ! control.nil?
        puts 'WARNING: You should always pass the control alternative through as the second argument with any other alternatives as the third because the order of the hash is not preserved in ruby 1.8'
      end

      # Check if array is passed to ab_test
      # e.g. ab_test('name', ['Alt 1', 'Alt 2', 'Alt 3'])
      if control.is_a? Array and alternatives.length.zero?
        control, alternatives = control.first, control[1..-1]
      end

      begin
        experiment_name_with_version, goals = normalize_experiment(metric_descriptor)
        experiment_name = experiment_name_with_version.to_s.split(':')[0]
        experiment = Split::Experiment.new(
          experiment_name,
          :alternatives => [control].compact + alternatives,
          :goals => goals)
        control ||= experiment.control && experiment.control.name

        ret = if Split.configuration.enabled
          experiment.save
          start_trial( Trial.new(:experiment => experiment, :users => split_id) )
        else
          control_variable(control)
        end
      rescue Errno::ECONNREFUSED => e
        raise(e) unless Split.configuration.db_failover
        Split.configuration.db_failover_on_db_error.call(e)

        if Split.configuration.db_failover_allow_parameter_override && override_present?(experiment_name)
          ret = override_alternative(experiment_name)
        end
      ensure
        ret ||= control_variable(control)
      end

      if block_given?
        if defined?(capture) # a block in a rails view
          block = Proc.new { yield(ret) }
          concat(capture(ret, &block))
          false
        else
          yield(ret)
        end
      else
        ret
      end
    end

    def finish_experiment(experiment, options = {})
      return true if experiment.has_winner? unless options[:skip_win_check]
      return false if !experiment.participating?(split_id)

      if options[:goals].any?
        options[:goals].each do |goal|
          trial = Trial.new(:experiment => experiment, :goals => Array(goal), :value => options[:value], :users => split_id)
          # trial.complete!() calls alternative.increment_completion
          # So this is where counts and values are incremented.
          call_trial_complete_hook(trial) if trial.complete!
        end
      else
        trial = Trial.new(:experiment => experiment, :goals => options[:goals], :value => options[:value], :users => split_id)
        call_trial_complete_hook(trial) if trial.complete!
      end
    end

    def finished(metric_descriptor, options = {})
      return if exclude_visitor? || Split.configuration.disabled?
      metric_descriptor, goals = normalize_experiment(metric_descriptor)
      experiments = Metric.possible_experiments(metric_descriptor)
    
      # redis optimization useful for when we're finishing a goal shared by
      # many experiments and want to eliminate N calls to redis
      extra_options = {}
      winners = Split.redis.with do |conn|
        conn.hgetall(:experiment_winner)
      end || {}

      Split::Experiment.preload_finished!(experiments, goals, split_id)
      Split::Experiment.preload_participating!(experiments, split_id)
      extra_options = { skip_win_check: true } # we skip the winner check so the goals continue to accumulate

      if experiments.any?
        experiments.each do |experiment|
          next unless winners[experiment.name].nil?
          finish_experiment(experiment, options.merge(goals: goals).merge(extra_options))
        end
      end
    rescue => e
      raise unless Split.configuration.db_failover
      Split.configuration.db_failover_on_db_error.call(e)
    end

    def override_present?(experiment_name)
      defined?(params) && params[experiment_name]
    end

    def override_alternative(experiment_name)
      params[experiment_name] if override_present?(experiment_name)
    end

    def default_present?(experiment_name)
      defined?(params) && params["#{experiment_name}_default"]
    end

    def default_alternative(experiment_name)
      params["#{experiment_name}_default"] if default_present?(experiment_name)
    end

    def begin_experiment_in_batch(experiment, users_and_alternative_names)
      # set user key fields
      Split::Persistence.adapter.set_values_in_batch(users_and_alternative_names, experiment.key)
      # check if experiment total participant count is enough. This should only be called once
      if experiment.has_enough_participants?
        experiment.set_end_time # this will also invoke on_experiment_end hook
        call_experiment_max_out_hook(experiment) 
      end
      # this method doesn't return meaningful value unlike begin_experiment
    end
    
    def begin_experiment(experiment)
      # check if experiment total participant count is enough. This should only be called once
      if experiment.has_enough_participants?
        experiment.set_end_time # this will also invoke on_experiment_end hook
        call_experiment_max_out_hook(experiment) 
      end
    end

    def ab_user
      @ab_user ||= Split::Persistence.adapter.new(self)
    end

    def split_id
      ab_user.key_frag
    end

    def exclude_visitor?
      instance_eval(&Split.configuration.ignore_filter)
    end

    def is_robot?
      defined?(request) && request.user_agent =~ Split.configuration.robot_regex
    end

    def is_ignored_ip_address?
      return false if Split.configuration.ignore_ip_addresses.empty?

      Split.configuration.ignore_ip_addresses.each do |ip|
        return true if defined?(request) && (request.ip == ip || (ip.class == Regexp && request.ip =~ ip))
      end
      false
    end

    protected

    def normalize_experiment(metric_descriptor)
      if Hash === metric_descriptor
        experiment_name = metric_descriptor.keys.first
        goals = Array(metric_descriptor.values.first)
      else
        experiment_name = metric_descriptor
        goals = []
      end
      return experiment_name, goals
    end

    def control_variable(control)
      Hash === control ? control.keys.first : control
    end

    def predetermined_alternative(experiment, check_winner = true)
      if override_present?(experiment.name) and experiment[override_alternative(experiment.name)]
        ret = override_alternative(experiment.name)
        # we always just go with the winner if already chosen
      elsif check_winner && experiment.has_winner?
        ret = experiment.winner.name
        # we go with the control if enough participants
      elsif experiment.has_enough_participants?
        ret = experiment.control.name
      else
        if exclude_visitor? || not_started?(experiment)
          ret = experiment.control.name
        else
          ret = nil
        end
      end
      ret
    end

    def start_trial(trial, check_winner = true)
      experiment = trial.experiment
      # if an alternative is specified in URL params, we change the user bucket to that alternative
      predetermined_alternative = predetermined_alternative(experiment)
      if predetermined_alternative
        ret = predetermined_alternative
      else
        if experiment.participating?(split_id) # stay in the same bucket if already bucketed
          ret = trial.choose[split_id].name
        else
          ret = trial.choose![split_id].name # this calls trial.record! which increments participant counts
          call_trial_choose_hook(trial)
          begin_experiment(experiment)
        end
      end

      ret
    end

    def not_started?(experiment)
      experiment.start_time.nil?
    end

    def call_experiment_max_out_hook(experiment)
      Split.configuration.on_experiment_max_out.call(self)
    end

    def call_trial_choose_hook(trial)
      send(Split.configuration.on_trial_choose, trial) if Split.configuration.on_trial_choose
    end

    def call_trial_complete_hook(trial)
      send(Split.configuration.on_trial_complete, trial) if Split.configuration.on_trial_complete
    end

    def keys_without_experiment(keys, experiment_key)
      keys.reject { |k| k.match(Regexp.new("^#{experiment_key}(:finished)?$")) }
    end
  end
end
