# this file needs to be mixed in to each framework
# ie Rails: action controller methods
module Multivariate
  module Helper
    def self.ab_test(experiment_name, *alternatives)
      experiment = Multivariate::Experiment.find_or_create(experiment_name, *alternatives)

      if current_user[experiment_name]
        return current_user[experiment_name]
      else
        alternative = experiment.random_alternative
        alternative.increment_participation
        current_user[experiment_name] = alternative.name
        return alternative.name
      end
    end
  
    def self.finished(experiment_name)
      experiment = Multivariate::Experiment.find(experiment_name)
      # find the experiment
      # find the current user
      # find the alternative that the current user is seeing for that experiment
      # increment the finished counter for that alternative of that experiment
    end

    def self.current_user
      @session ||= {}
    end

    def self.current_user=(hash)
      @session = hash
    end
  end
end