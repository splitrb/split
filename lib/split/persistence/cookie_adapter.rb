require "json"

module Split
  module Persistence
    class CookieAdapter

      def initialize(context)
        @cookies = context.send(:cookies)
        @expires = Time.now + cookie_length_config
      end

      def [](key)
        hash[key]
      end

      def []=(key, value)
        set_cookie(hash.merge(key => value))
      end

      def delete(key)
        set_cookie(hash.tap { |h| h.delete(key) })
      end

      def keys
        hash.keys
      end

      private

      def set_cookie(value)
        @cookies[:split] = {
          :value => JSON.generate(value),
          :expires => @expires
        }
      end

      def hash
        if @cookies[:split]
          begin
            JSON.parse(@cookies[:split])
          rescue JSON::ParserError
            {}
          end
        else
          {}
        end
      end

      def cookie_length_config
        Split.configuration.persistence_cookie_length
      end

    end
  end
end
