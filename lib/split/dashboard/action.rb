# frozen_string_literal: true

module Split
  class Dashboard
    class Action
      include Rendering
      include Split::Helper

      def initialize(env, block)
        @action = block
        @env = env
      end

      def call
        instance_eval(&@action)
      end

      def request
        @request ||= Rack::Request.new(@env)
      end

      def response
        @response ||= Rack::Response.new
      end

      def params
        request.params
      end
    end
  end
end
