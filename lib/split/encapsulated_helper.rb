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

    class ContextShim
      include Split::Helper
      public :ab_test, :finished

      def initialize(context)
        @context = context
      end

      def ab_user
        @ab_user ||= Split::Persistence.adapter.new(@context)
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

    def ab_test_finished(*arguments)
      split_context_shim.finished *arguments
    end

    private

    # instantiate and memoize a context shim in case of multiple ab_test* calls
    def split_context_shim
      @split_context_shim ||= ContextShim.new(self)
    end
  end
end
