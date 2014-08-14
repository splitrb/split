require "json"

module Split
  module Persistence
    class CookieAdapter

      EXPIRES = Time.now + 31536000 # One year from now

      def initialize(context)
        @cookies = context.send(:cookies)
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
        @cookies[:tomo_split] = {
          :value => JSON.generate(value),
          :expires => EXPIRES,
          :domain => "touchofmodern.com"
        }
      end

      def hash
        if @cookies[:tomo_split]
          begin
            JSON.parse(@cookies[:tomo_split])
          rescue JSON::ParserError
            {}
          end
        else
          {}
        end
      end

    end
  end
end
