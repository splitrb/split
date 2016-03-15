module Split
  module Helper

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
          start_trial( Trial.new(:experiment => experiment, :user => ab_user_split_id) )
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

    def reset!(experiment, goal=nil)
      if !goal
        ab_user.delete(experiment.key)
      else
        ab_user.delete(experiment.finished_key(goal))
      end
    end

    def finish_experiment(experiment, options = {:reset => true})
      return true if experiment.has_winner? unless options[:skip_win_check]
      should_reset = experiment.resettable? && options[:reset]
      
      alternative_name = 
        if options[:alternatives]
          options[:alternatives][experiment.key]
        else 
          ab_user[experiment.key]
        end
      if options[:goals].any?
        options[:goals].each do |goal|
          # if the goal is finished and not resettable, we call it a day
          goal_is_finished = 
            if options[:finished_goals] # sometimes we pass in finished goals
              options[:finished_goals][experiment.finished_key(goal)]
            else # other times we have to query redis to get finished goals for this user
              ab_user[experiment.finished_key(goal)]
            end
          if goal_is_finished && !should_reset
            return true
          else
            trial = Trial.new(:experiment => experiment, :alternative => alternative_name, :goals => Array(goal), :value => options[:value], :user => ab_user_split_id)
            # trial.complete!() calls alternative.increment_completion
            # So this is where counts and values are incremented. 
            trial.complete!() 
            call_trial_complete_hook(trial)

            if should_reset # reset the goal if it's resettable
              reset!(experiment, goal)
            else # if not resettable we say that this user has finished this goal
              ab_user[experiment.finished_key(goal)] = true
            end
          end
        end
      else
        if ab_user[experiment.finished_key] && !should_reset
          return true
        else
          trial = Trial.new(:experiment => experiment, :alternative => alternative_name, :goals => options[:goals], :value => options[:value], :user => ab_user_split_id)
          call_trial_complete_hook(trial) if trial.complete!

          if should_reset
            reset!(experiment)
          else
            ab_user[experiment.finished_key] = true
          end
        end
      end
    end

    def finished(metric_descriptor, options = {:reset => true})
      return if exclude_visitor? || Split.configuration.disabled?
      metric_descriptor, goals = normalize_experiment(metric_descriptor)
      experiments = Metric.possible_experiments(metric_descriptor)
    
      
      # redis optimization useful for when we're finishing a goal shared by 
      # many experiments and want to eliminate N calls to redis
      extra_options = {}
      winners = {}
      if (ab_user.respond_to? :hmget)
        winners = Split.redis.with do |conn|
          conn.hgetall(:experiment_winner)
        end || {}
        
        keys = experiments.map(&:key)
    
        alternatives = ab_user.hmget(keys)
        alt_map = Hash[*keys.zip(alternatives).flatten]
        
        exp_finished_goal_keys = []
        goals.each do |goal|
          experiments.each do |experiment|
            exp_finished_goal_keys << experiment.finished_key(goal)
          end
        end
        finished_goals = ab_user.hmget(exp_finished_goal_keys)
        goal_map = Hash[*exp_finished_goal_keys.zip(finished_goals).flatten]
        extra_options = { skip_win_check: true, # we skip the winner check so the goals continue to accumulate
                          alternatives: alt_map,
                          finished_goals: goal_map }
      end
      
      if experiments.any?
        experiments.each do |experiment|
          next unless winners[experiment.name].nil?
          experiment.has_no_winner! # we falsify has_winner so the counts continue to accumulate
          finish_experiment(experiment, options.merge(goals: goals)
                                               .merge(extra_options))
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

    def begin_experiment(experiment, alternative_name = nil)
      alternative_name ||= experiment.control.name
      # check if experiment total participant count is enough. This should only be called once
      if experiment.has_enough_participants?
        experiment.set_end_time # this will also invoke on_experiment_end hook
        call_experiment_max_out_hook(experiment) 
      end
      ab_user[experiment.key] = alternative_name
      alternative_name
    end

    def ab_user_split_id
      if ab_user.respond_to? :split_id
        ab_user.split_id
      else
        nil
      end
    end

    def ab_user
      @ab_user ||= Split::Persistence.adapter.new(self)
    end

    def exclude_visitor?
      instance_eval(&Split.configuration.ignore_filter)
    end

    def not_allowed_to_test?(experiment_key)
      !Split.configuration.allow_multiple_experiments && doing_other_tests?(experiment_key)
    end

    def doing_other_tests?(experiment_key)
      keys_without_experiment(ab_user.keys, experiment_key).length > 0
    end

    def clean_old_versions(experiment)
      old_versions(experiment).each do |old_key|
        ab_user.delete old_key
      end
    end

    def old_versions(experiment)
      if experiment.version > 0
        keys = ab_user.keys.select { |k| k.match(Regexp.new(experiment.name)) }
        keys_without_experiment(keys, experiment.key)
      else
        []
      end
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

    def start_trial(trial, check_winner = true)
      experiment = trial.experiment
      # if an alternative is specified in URL params, we change the user bucket to that alternative
      if override_present?(experiment.name) and experiment[override_alternative(experiment.name)]
        if Split.configuration.store_override
          ret = override_alternative(experiment.name)
          ab_user[experiment.key] = ret 
          trial.alternative = ret
          call_trial_choose_hook(trial)
        end
      # we always just go with the winner if already chosen
      elsif check_winner && experiment.has_winner?
        ret = experiment.winner.name
      # we go with the control if enough participants
      elsif experiment.has_enough_participants? 
        ret = experiment.control.name
      else
        clean_old_versions(experiment) # remove previous versions from Redis
        if exclude_visitor? || not_allowed_to_test?(experiment.key) || not_started?(experiment)
          ret = experiment.control.name
        else
          if ab_user[experiment.key] # stay in the same bucket if already bucketed
            ret = ab_user[experiment.key]
          # when a default alternative is given in URL params and the user is not bucketed yet
          elsif default_present?(experiment.name) and experiment[default_alternative(experiment.name)]
            trial.alternative = default_alternative(experiment.name)
            trial.record! # increment participant counts
            call_trial_choose_hook(trial)
            # bucket the user into the altnerative and store in Redis
            ret = begin_experiment(experiment, trial.alternative.name)
          else
            trial.choose! # this calls trial.record! which increments participant counts
            call_trial_choose_hook(trial)
            ret = begin_experiment(experiment, trial.alternative.name)
          end
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
