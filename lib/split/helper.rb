module Split
  module Helper

    def ab_test(experiment_name, control=nil, *alternatives)
      if RUBY_VERSION.match(/1\.8/) && alternatives.length.zero?
        puts 'WARNING: You should always pass the control alternative through as the second argument with any other alternatives as the third because the order of the hash is not preserved in ruby 1.8'
      end

      begin
        ret = if Split.configuration.enabled
          load_and_start_trial(experiment_name, control, alternatives)
        else
          control_variable(control)
        end

      rescue => e
        raise(e) unless Split.configuration.db_failover
        Split.configuration.db_failover_on_db_error.call(e)

        if Split.configuration.db_failover_allow_parameter_override && override_present?(experiment_name)
          ret = override_alternative(experiment_name)
        end
      ensure
        if ret.nil?
          ret = control_variable(control)
        end
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
      should_reset = experiment.resettable? && options[:reset]
      if ab_user[experiment.finished_key] && !should_reset
        return true
      else
        alternative_name = ab_user[experiment.key]
        trial = Trial.new(experiment: experiment, alternative_name: alternative_name)
        trial.complete!
        if should_reset
          reset!(experiment)
        else
          ab_user[experiment.finished_key] = true
        end
      end
    end


    def finished(metric_name, options = {:reset => true})
      return if exclude_visitor? || Split.configuration.disabled?
      experiments = Metric.possible_experiments(metric_name)

      if experiments.any?
        experiments.each do |experiment|
          finish_experiment(experiment, options)
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
      is_robot? || is_ignored_ip_address?
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
      request.user_agent =~ Split.configuration.robot_regex
    end

    def is_ignored_ip_address?
      if Split.configuration.ignore_ip_addresses.any?
        Split.configuration.ignore_ip_addresses.include?(request.ip)
      else
        false
      end
    end

    protected

    def control_variable(control)
      Hash === control ? control.keys.first : control
    end

    def load_and_start_trial(experiment_name, control, alternatives)
      if control.nil? && alternatives.length.zero?
        experiment = Experiment.find(experiment_name)

        raise ExperimentNotFound("#{experiment_name} not found") if experiment.nil?
      else
        experiment = Split::Experiment.find_or_create(experiment_name, *([control] + alternatives))
      end

      start_trial( Trial.new(experiment: experiment) )
    end

    def start_trial(trial)
      experiment = trial.experiment
      if override_present?(experiment.name)
        ret = override_alternative(experiment.name)
      else
        clean_old_versions(experiment)
        if exclude_visitor? || not_allowed_to_test?(experiment.key)
          ret = experiment.control.name
        else
          if ab_user[experiment.key]
            ret = ab_user[experiment.key]
          else
            trial.choose!
            ret = begin_experiment(experiment, trial.alternative.name)
          end
        end
      end

      ret
    end

    def keys_without_experiment(keys, experiment_key)
      keys.reject { |k| k.match(Regexp.new("^#{experiment_key}(:finished)?$")) }
    end

    #   def normalize_variants(variants)
    #     given_probability, num_with_probability = variants.inject([0,0]) do |a,v|
    #       p, n = a
    #       if v.kind_of?(Hash) && v[:percent]
    #         [p + v[:percent], n + 1]
    #       else
    #         a
    #       end
    #     end
    # 
    #     num_without_probability = variants.length - num_with_probability
    #     unassigned_probability = ((100.0 - given_probability) / num_without_probability / 100.0)
    # 
    #     if num_with_probability.nonzero?
    #       variants = variants.map do |v|
    #         if v.kind_of?(Hash) && v[:name] && v[:percent]
    #           { v[:name] => v[:percent] / 100.0 }
    #         elsif v.kind_of?(Hash) && v[:name]
    #           { v[:name] => unassigned_probability }
    #         else
    #           { v => unassigned_probability }
    #         end
    #       end
    #       [variants.shift, variants]
    #     else
    #       variants = variants.dup
    #       [variants.shift, variants]
    #     end
    #   end
  end
end
