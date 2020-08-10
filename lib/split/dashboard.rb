# frozen_string_literal: true

require 'split'
require 'split/dashboard/web'

module Split
  class Dashboard
    class << self
      def middlewares
        @middlewares ||= []
      end

      def use(*middleware_args, &block)
        middlewares << [middleware_args, block]
      end
    end

    def self.call(env)
      @dashboard ||= new
      @dashboard.call(env)
    end

    def call(env)
      app.call(env)
    end

    def app
      @app ||= begin
        middlewares = self.class.middlewares

        Rack::Builder.new do
          use Rack::MethodOverride
          run Split::Dashboard::Web

          middlewares.each { |middleware, block| use(*middleware, &block) }
        end
      end
    end
  end
end
