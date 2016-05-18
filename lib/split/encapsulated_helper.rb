# Split's helper exposes all kinds of methods we don't want to
# mix into our model classes.
#
# This module exposes only two methods
#  - ab_test and 
#  - ab_test_finished
# that can safely be mixed into any class.
#
# Passes the instance of the class that it's mixed into to the
# Split persistence adapter as context.
#
module Split
  module EncapsulatedHelper
    
    def self.included(base)
        base.extend(ClassMethods)
    end
    
    class ContextShim
      include Split::Helper
      def initialize(context, original_params)
        @context = context
        @_params = original_params
      end
      def ab_user
        @ab_user ||= Split::Persistence.adapter.new(@context)
      end
      def params
        @_params
      end
    end

    def ab_test(*arguments)
      ret = split_context_shim.ab_test(*arguments)
      # TODO there must be a better way to pass a block straight
      # through to the original ab_test
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
    module ClassMethods
      def get_experiment_info(experiment_name)
        exp = Split::Experiment.find(experiment_name)
        if exp.nil?
          return nil
        else
          exp.load_from_redis
          return exp.to_hash
        end
      end

      def get_alternative_percentage(experiment_name, alternative_name)
        exp = Split::Experiment.find(experiment_name)
        return nil if exp.nil?
        exp.load_from_redis
        alternative = exp.alternatives.find{|alt| alt.name == alternative_name}
        return alternative.nil? ? nil : {percentage: alternative.weight, version: exp.version}
      end
    end
    
    def ab_test_finished(*arguments)
      split_context_shim.finished *arguments
    end

    private

    # instantiate and memoize a context shim in case of multiple ab_test* calls
    def split_context_shim
      _params = defined?(params) ? params : {}
      @split_context_shim ||= ContextShim.new(self, _params)
    end
  end
end
