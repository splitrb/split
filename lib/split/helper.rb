module Split
  module Helper
    def ab_test(experiment_name, *alternatives, &block)
      experiment = Split::Experiment.find_or_create(experiment_name, *alternatives)
      if experiment.winner
        ret = experiment.winner.name
      else
        if forced_alternative = override(experiment_name, alternatives)
          ret = forced_alternative
        else
          ab_user[experiment_name] = experiment.control.name if exclude_visitor?

          if ab_user[experiment_name]
            ret = ab_user[experiment_name]
          else
            alternative = experiment.next_alternative
            alternative.increment_participation
            ab_user[experiment_name] = alternative.name
            ret = alternative.name
          end
        end
      end

      ret = yield(ret) if block_given?
      ret
    end

    def finished(experiment_name)
      return if exclude_visitor?
      alternative_name = ab_user[experiment_name]
      alternative = Split::Alternative.find(alternative_name, experiment_name)
      alternative.increment_completion
      session[:split].delete(experiment_name)
    end

    def override(experiment_name, alternatives)
      return params[experiment_name] if defined?(params) && alternatives.include?(params[experiment_name])
    end

    def ab_user
      session[:split] ||= {}
    end

    def exclude_visitor?
      is_robot? or is_ignored_ip_address?
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
  end
end
