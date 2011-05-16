# this file needs to be mixed in to each framework
# ie Rails: action controller methods
module Multivariate
  module Helper
    def ab_test(experiment_name, *alternatives)
      experiment = Multivariate::Experiment.find_or_create(experiment_name, *alternatives)

      if ab_user[experiment_name]
        return ab_user[experiment_name]
      else
        alternative = experiment.random_alternative
        alternative.increment_participation
        ab_user[experiment_name] = alternative.name
        return alternative.name
      end
    end
  
    def finished(experiment_name)
      alternative_name = ab_user[experiment_name]
      alternative = Multivariate::Alternative.find(alternative_name, experiment_name)
      alternative.increment_completion
    end

    def ab_user
      session[:multivariate] ||= {}
    end
  end
end
