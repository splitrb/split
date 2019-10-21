# frozen_string_literal: true
module Split
  module Helper
    OVERRIDE_PARAM_NAME = "ab_test"

    module_function

    def ab_test(metric_descriptor, control = nil, *alternatives)
      begin
        experiment = ExperimentCatalog.find_or_initialize(metric_descriptor, control, *alternatives)
        alternative = if Split.configuration.enabled && !exclude_visitor?
          experiment.save
          raise(Split::InvalidExperimentsFormatError) unless (Split.configuration.experiments || {}).fetch(experiment.name.to_sym, {})[:combined_experiments].nil?
          trial = Trial.new(:user => ab_user, :experiment => experiment,
              :override => override_alternative(experiment.name), :exclude => exclude_visitor?,
              :disabled => split_generically_disabled?)
          alt = trial.choose!(self)
          alt ? alt.name : nil
        else
          control_variable(experiment.control)
        end
      rescue Errno::ECONNREFUSED, Redis::BaseError, SocketError => e
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
      return false if active_experiments[experiment.name].nil?
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

    def ab_finished(metric_descriptor, options = {:reset => true})
      return if exclude_visitor? || Split.configuration.disabled?
      metric_descriptor, goals = normalize_metric(metric_descriptor)
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

    def ab_record_extra_info(metric_descriptor, key, value = 1)
      return if exclude_visitor? || Split.configuration.disabled?
      metric_descriptor, _ = normalize_metric(metric_descriptor)
      experiments = Metric.possible_experiments(metric_descriptor)

      if experiments.any?
        experiments.each do |experiment|
          alternative_name = ab_user[experiment.key]

          if alternative_name
            alternative = experiment.alternatives.find{|alt| alt.name == alternative_name}
            alternative.record_extra_info(key, value) if alternative
          end
        end
      end
    rescue => e
      raise unless Split.configuration.db_failover
      Split.configuration.db_failover_on_db_error.call(e)
    end

    def ab_active_experiments()
      ab_user.active_experiments
    rescue => e
      raise unless Split.configuration.db_failover
      Split.configuration.db_failover_on_db_error.call(e)
    end


    def override_present?(experiment_name)
      override_alternative(experiment_name)
    end

    def override_alternative(experiment_name)
      defined?(params) && params[OVERRIDE_PARAM_NAME] && params[OVERRIDE_PARAM_NAME][experiment_name]
    end

    def split_generically_disabled?
      defined?(params) && params['SPLIT_DISABLE']
    end

    def ab_user
      @ab_user ||= User.new(self)
    end

    def exclude_visitor?
      defined?(request) && (instance_exec(request, &Split.configuration.ignore_filter) || is_ignored_ip_address? || is_robot? || is_preview?)
    end

    def is_robot?
      defined?(request) && request.user_agent =~ Split.configuration.robot_regex
    end

    def is_preview?
      defined?(request) && defined?(request.headers) && request.headers['x-purpose'] == 'preview'
    end

    def is_ignored_ip_address?
      return false if Split.configuration.ignore_ip_addresses.empty?

      Split.configuration.ignore_ip_addresses.each do |ip|
        return true if defined?(request) && (request.ip == ip || (ip.class == Regexp && request.ip =~ ip))
      end
      false
    end

    def active_experiments
      ab_user.active_experiments
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
