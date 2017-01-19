# frozen_string_literal: true
require "split/helper"

# Split's helper exposes all kinds of methods we don't want to
# mix into our model classes.
#
# This module exposes only two methods:
#  - ab_test()
#  - ab_finished()
# that can safely be mixed into any class.
#
# Passes the instance of the class that it's mixed into to the
# Split persistence adapter as context.
#
module Split
  module EncapsulatedHelper

    class ContextShim
      include Split::Helper
      public :ab_test, :ab_finished

      def initialize(context)
        @context = context
      end

      def ab_user
        @ab_user ||= Split::User.new(@context)
      end
    end

    def ab_test(*arguments,&block)
      split_context_shim.ab_test(*arguments,&block)
    end

    private

    # instantiate and memoize a context shim in case of multiple ab_test* calls
    def split_context_shim
      @split_context_shim ||= ContextShim.new(self)
    end
  end
end
