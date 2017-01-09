# frozen_string_literal: true
module Split
  module Persistence
    class RedisAdapter
      DEFAULT_CONFIG = { namespace: 'persistence' }.freeze

      attr_reader :redis_key

      def initialize(context, key = nil)
        if key
          @redis_key = "#{self.class.config[:namespace]}:#{key}"
        elsif (lookup_by = self.class.config[:lookup_by])
          key_frag =
            if lookup_by.respond_to?(:call)
              lookup_by.call(context)
            else
              context.send(lookup_by)
            end
          @redis_key = "#{self.class.config[:namespace]}:#{key_frag}"
        else
          raise 'Please configure lookup_by'
        end
      end

      def [](field)
        Split.redis.hget(redis_key, field)
      end

      def multi_get(*fields)
        Split.redis.hmget(redis_key, *fields)
      end

      def []=(field, value)
        Split.redis.multi do
          Split.redis.hset(redis_key, field, value)
          expire_seconds = self.class.config[:expire_seconds]
          Split.redis.expire(redis_key, expire_seconds) if expire_seconds
        end
      end

      def delete(*fields)
        Split.redis.hdel(redis_key, fields)
      end

      def keys
        Split.redis.hkeys(redis_key)
      end

      def self.with_config(options = {})
        config.merge!(options)
        self
      end

      def self.config
        @config ||= DEFAULT_CONFIG.dup
      end

      def self.reset_config!
        @config = DEFAULT_CONFIG.dup
      end
    end
  end
end
