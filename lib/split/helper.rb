module Split
  module Helper
    def ab_test(experiment_name, *alternatives)
      experiment = Split::Experiment.find_or_create(experiment_name, *alternatives)
      return experiment.winner.name if experiment.winner

      if forced_alternative = override(experiment_name, alternatives)
        return forced_alternative
      end

      if ab_user[experiment_name]
        return ab_user[experiment_name]
      else
        alternative = experiment.next_alternative
        alternative.increment_participation
        ab_user[experiment_name] = alternative.name
        return alternative.name
      end
    end

    def finished(experiment_name)
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
  end
end
