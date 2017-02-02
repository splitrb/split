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
        redis_data[field.to_s]
      end

      def multi_get(*fields)
        fields.map { |field| redis_data[field.to_s] }
      end

      def []=(field, value)
        Split.redis.multi do
          Split.redis.hset(redis_key, field, value)
          expire_seconds = self.class.config[:expire_seconds]
          Split.redis.expire(redis_key, expire_seconds) if expire_seconds
        end
        redis_data[field.to_s] = value
      end

      def delete(*fields)
        Split.redis.hdel(redis_key, fields)
        fields.each { |field| redis_data.delete(field.to_s) }
      end

      def keys
        redis_data.keys
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

      private

      def redis_data
        return @redis_data if defined?(@redis_data)
        @redis_data = Split.redis.hgetall(redis_key)
      end
    end # RedisPersistence
  end # Persistence
end # Split
