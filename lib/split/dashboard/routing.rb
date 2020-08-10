# frozen_string_literal: true

module Split
  class Dashboard
    module Routing
      STATIC_RACK = Rack::File.new(
        File.join(
          File.dirname(File.expand_path(__FILE__)),
          'public'
        )
      )

      def self.included(mod)
        mod.extend(ClassMethods)
      end

      module ClassMethods
        def call(env)
          route = route_for(env["REQUEST_METHOD"], env["PATH_INFO"])

          if route
            Action.new(env, route).call
          else
            STATIC_RACK.call(env)
          end
        end

        def get(path, &block)
          key = ['GET', path]
          routes[key] = block
        end

        def post(path, &block)
          key = ['POST', path]
          routes[key] = block
        end

        def delete(path, &block)
          key = ['DELETE', path]
          routes[key] = block
        end

        def routes
          @routes ||= Hash.new
        end

        def route_for(method, path)
          path = '/' if path.empty?
          key = [method, path]
          routes[key]
        end
      end
    end
  end
end
