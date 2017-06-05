# frozen_string_literal: true
require "json"

module Split
  module Persistence
    class CookieAdapter

      def initialize(context)
        @request, @response = context.request, context.response
        @cookies = @request.cookies
        @expires = Time.now + cookie_length_config
      end

      def [](key)
        hash[key.to_s]
      end

      def []=(key, value)
        set_cookie(hash.merge!(key.to_s => value))
      end

      def delete(key)
        set_cookie(hash.tap { |h| h.delete(key.to_s) })
      end

      def keys
        hash.keys
      end

      private

      def set_cookie(value = {})
        @response.set_cookie :split.to_s, default_options.merge(value: JSON.generate(value))
      end

      def default_options
        { expires: @expires, path: '/' }
      end

      def hash
        @hash ||= begin
          if cookies = @cookies[:split.to_s]
            begin
              JSON.parse(cookies)
            rescue JSON::ParserError
              {}
            end
          else
            {}
          end
        end
      end

      def cookie_length_config
        Split.configuration.persistence_cookie_length
      end

    end
  end
end
