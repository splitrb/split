module Split
  module Helper
    def ab_test(experiment_name, control, *alternatives)
      if RUBY_VERSION.match(/1\.8/) && alternatives.length.zero?
        puts 'WARNING: You should always pass the control alternative through as the second argument with any other alternatives as the third because the order of the hash is not preserved in ruby 1.8'
      end

      ret = if Split.configuration.enabled
              experiment_variable(alternatives, control, experiment_name)
            else
              control_variable(control)
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

    def finished(experiment_name, options = {:reset => true})
      return if exclude_visitor? or !Split.configuration.enabled
      return unless (experiment = Split::Experiment.find(experiment_name))
      return if !options[:reset] && ab_user[experiment.finished_key]

      if alternative_name = ab_user[experiment.key]
        alternative = Split::Alternative.new(alternative_name, experiment_name)
        alternative.increment_completion

        if options[:reset]
          ab_user.delete(experiment.key)
        else
          ab_user[experiment.finished_key] = true
        end
      end
    rescue => e
      raise unless Split.configuration.db_failover
      Split.configuration.db_failover_on_db_error.call(e)
    end

    def override(experiment_name, alternatives)
      params[experiment_name] if defined?(params) && alternatives.include?(params[experiment_name])
    end

    def begin_experiment(experiment, alternative_name = nil)
      alternative_name ||= experiment.control.name
      ab_user[experiment.key] = alternative_name
    end

    def ab_user
      @ab_user ||= Split::Persistence.adapter.new(self)
    end

    def exclude_visitor?
      is_robot? or is_ignored_ip_address?
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

    def experiment_variable(alternatives, control, experiment_name)
      begin
        experiment = Split::Experiment.find_or_create(experiment_name, *([control] + alternatives))
        if experiment.winner
          ret = experiment.winner.name
        else
          if forced_alternative = override(experiment.name, experiment.alternative_names)
            ret = forced_alternative
          else
            clean_old_versions(experiment)
            begin_experiment(experiment) if exclude_visitor? or not_allowed_to_test?(experiment.key)

            if ab_user[experiment.key]
              ret = ab_user[experiment.key]
            else
              alternative = experiment.next_alternative
              alternative.increment_participation
              begin_experiment(experiment, alternative.name)
              ret = alternative.name
            end
          end
        end
      rescue => e
        raise unless Split.configuration.db_failover
        Split.configuration.db_failover_on_db_error.call(e)
        if Split.configuration.db_failover_allow_parameter_override
          all_alternatives = *([control] + alternatives)
          alternative_names = all_alternatives.map{|a| a.is_a?(Hash) ? a.keys : a}.flatten
          ret = override(experiment_name, alternative_names)
        end
        unless ret
          ret = control_variable(control)
        end
      end
      ret
    end

    def keys_without_experiment(keys, experiment_key)
      keys.reject { |k| k.match(Regexp.new("^#{experiment_key}(:finished)?$")) }
    end
  end

end
