# this file needs to be mixed in to each framework
# ie Rails: action controller methods
module Multivariate
  module Helpers
    def ab_test(experiment_name, *alternatives)
      experiment = Multivariate::Experiment.find_or_create(experiment_name, *alternatives)
    
      # find current user
    
      # is the current user is participating in the experiment already?
        # return their alternative
      # otherwise
        # give the current user an alternative (trying to get equal number of participents in each alternative)
        # increment the counter for the that alterntives
        # return the alternative
    end
  
    def finished(experiment_name)
      experiment = Multivariate::Experiment.find(experiment_name)
      # find the experiment
      # find the current user
      # find the alternative that the current user is seeing for that experiment
      # increment the finished counter for that alternative of that experiment
    end
  end
end