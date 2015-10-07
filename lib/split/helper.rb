module Split
  module Helper
    module_function

    def ab_test(metric_descriptor, control = nil, *alternatives)
      begin
        experiment = ExperimentCatalog.find_or_initialize(metric_descriptor, control, *alternatives)

        alternative = if Split.configuration.enabled
          experiment.save
          trial = Trial.new(:user => ab_user, :experiment => experiment,
              :override => override_alternative(experiment.name), :exclude => exclude_visitor?(experiment),
              :disabled => split_generically_disabled?)
          alt = trial.choose!(self)
          alt ? alt.name : nil
        else
          control_variable(experiment.control)
        end
      rescue Errno::ECONNREFUSED, Redis::CannotConnectError, SocketError => e
        raise(e) unless Split.configuration.db_failover
        Split.configuration.db_failover_on_db_error.call(e)

        if Split.configuration.db_failover_allow_parameter_override
          alternative = override_alternative(experiment.name) if override_present?(experiment.name)
          alternative = control_variable(experiment.control) if split_generically_disabled?
        end
      ensure
        alternative ||= control_variable(experiment.control)
      end

      if block_given?
        metadata = trial ? trial.metadata : {}
        yield(alternative, metadata)
      else
        alternative
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
        trial = Trial.new(:user => ab_user, :experiment => experiment,
              :alternative => alternative_name)
        trial.complete!(options[:goals], self)

        if should_reset
          reset!(experiment)
        else
          ab_user[experiment.finished_key] = true
        end
      end
    end

    def finished(metric_descriptor, options = {:reset => true})
      return if Split.configuration.disabled?
      metric_descriptor, goals = normalize_metric(metric_descriptor)
      experiments = Metric.possible_experiments(metric_descriptor)

      if experiments.any?
        experiments.each do |experiment|
          next if exclude_visitor?(experiment)
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

    def split_generically_disabled?
      defined?(params) && params['SPLIT_DISABLE']
    end

    def begin_experiment(experiment, alternative_name = nil)
      alternative_name ||= experiment.control.name
      ab_user[experiment.key] = alternative_name
      alternative_name
    end

    # alternative can be either a string or an array of strings
    def ensure_alternative_or_exclude(experiment_name, alternatives)
      alternatives = Array(alternatives)
      experiment   = ExperimentCatalog.find(experiment_name)

      # This is called if the experiment is not yet created. Since we can't created (we need the alternatives
      # configuration to be passed to this method), we exclude the user, and when `ab_test` is called after
      # the experiment is created. This means the first user will be excluded from the test and will have
      # the control alternative
      if !experiment
        experiment = Experiment.new(experiment_name)
        exclude_visitor(experiment)
        return
      end

      # If the user doesn't have an alternative set, we override the alternative and we manually increment the
      # participant count, since split doesn't do it when an alternative is overriden
      unless ab_user[experiment.key]
        params[experiment_name] = ab_user[experiment.key] = alternatives.sample
        Split::Alternative.new(ab_user[experiment.key], experiment_name).increment_participation
        return
      end

      current_alternative = ab_user[experiment.key]

      # We don't decrement the participant count if the visitor is included or if the desired alternative
      # was already chosen by split before
      if exclude_visitor?(experiment) || alternatives.include?(current_alternative)
        params[experiment_name] ||= current_alternative
        return
      end

      # We decrement the participant count if the desired alternative was not chosen by split before
      Split::Alternative.new(current_alternative, experiment_name).decrement_participation
      params[experiment_name] = ab_user[experiment.key] = alternatives.sample
      exclude_visitor(experiment)
    end

    def exclude_visitor(experiment)
      ab_user[experiment.excluded_key] = true
    end

    def ab_user
      @ab_user ||= Split::Persistence.adapter.new(self)
    end

    def exclude_visitor?(experiment)
      instance_eval(&Split.configuration.ignore_filter) || is_ignored_ip_address? || is_robot? || ab_user[experiment.excluded_key]
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

    def active_experiments
      experiment_pairs = {}
      ab_user.keys.each do |key|
        key_without_version = key.split(/\:\d(?!\:)/)[0]
        Metric.possible_experiments(key_without_version).each do |experiment|
          if !experiment.has_winner? and !ab_user.keys.include?(experiment.excluded_key)
            experiment_pairs[key_without_version] = ab_user[key]
          end
        end
      end
      return experiment_pairs
    end

    def normalize_metric(metric_descriptor)
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
      Hash === control ? control.keys.first.to_s : control.to_s
    end
  end
end
