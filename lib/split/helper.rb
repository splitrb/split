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
          start_trial( Trial.new(:experiment => experiment) )
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

    def reset!(experiment)
      ab_user.delete(experiment.key)
    end

    def finish_experiment(experiment, options = {:reset => true})
      return true if experiment.has_winner?
      should_reset = experiment.resettable? && options[:reset]
      if ab_user[experiment.finished_key] && !should_reset
        return true
      else
        alternative_name = ab_user[experiment.key]
        trial = Trial.new(:experiment => experiment, :alternative => alternative_name, :goals => options[:goals])
        call_trial_complete_hook(trial) if trial.complete!

        if should_reset
          reset!(experiment)
        else
          ab_user[experiment.finished_key] = true
        end
      end
    end


    def finished(metric_descriptor, options = {:reset => true})
      return if exclude_visitor? || Split.configuration.disabled?
      metric_descriptor, goals = normalize_experiment(metric_descriptor)
      experiments = Metric.possible_experiments(metric_descriptor)

      if experiments.any?
        experiments.each do |experiment|
          finish_experiment(experiment, options.merge(:goals => goals))
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

    def begin_experiment(experiment, alternative_name = nil)
      alternative_name ||= experiment.control.name
      ab_user[experiment.key] = alternative_name
      alternative_name
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

    def start_trial(trial)
      experiment = trial.experiment
      if override_present?(experiment.name)
        ret = override_alternative(experiment.name)
        ab_user[experiment.key] = ret if Split.configuration.store_override
      elsif experiment.has_winner?
        ret = experiment.winner.name
      else
        clean_old_versions(experiment)
        if exclude_visitor? || not_allowed_to_test?(experiment.key) || not_started?(experiment)
          ret = experiment.control.name
        else
          if ab_user[experiment.key]
            ret = ab_user[experiment.key]
          else
            trial.choose!
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
