module Split
  class Dashboard
    module Routing

      def self.included(mod)
        mod.extend(ClassMethods)
      end

      module ClassMethods
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
          key = [method, path]
          routes[key]
        end
      end
    end
  end
end
