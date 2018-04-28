# frozen_string_literal: true
require "json"

module Split
  module Persistence
    class CookieAdapter

      def initialize(context)
        @context = context
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
        cookie_key = :split.to_s
        cookie_value = default_options.merge(value: JSON.generate(value))
        if action_dispatch?
          @context.cookies[cookie_key] = cookie_value
        else
          set_cookie_via_rack(cookie_key, cookie_value)
        end
      end

      def default_options
        { expires: @expires, path: '/' }
      end

      def set_cookie_via_rack(key, value)
        header = Rack::Utils.make_delete_cookie_header(@response.set_cookie_header, key, value)
        new_header = Rack::Utils.add_cookie_to_header(header, key, value)
        @response.set_cookie_header = new_header
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

      def action_dispatch?
        defined?(Rails) && @response.is_a?(ActionDispatch::Response)
      end
    end
  end
end
