module Split
  module Persistence
    class RedisAdapter
      DEFAULT_CONFIG = {:namespace => 'persistence'}.freeze

      attr_reader :redis_key

      def initialize(context)
        if lookup_by = self.class.config[:lookup_by]
          if lookup_by.respond_to?(:call)
            key_frag = lookup_by.call(context)
          else
            key_frag = context.send(lookup_by)
          end
          @redis_key = "#{self.class.config[:namespace]}:#{key_frag}"
        else
          raise "Please configure lookup_by"
        end
      end

      def [](field)
        Split.redis.with do |conn|
          conn.hget(redis_key, field)
        end
      end
      
      def hmget(fields)
        puts fields
        Split.redis.with do |conn|
          conn.hmget(redis_key, fields)
        end
      end

      def []=(field, value)
        Split.redis.with do |conn|
          conn.hset(redis_key, field, value)
        end
      end

      def delete(field)
        Split.redis.with do |conn|
          conn.hdel(redis_key, field)
        end
      end

      def keys
        Split.redis.with do |conn|
          conn.hkeys(redis_key)
        end
      end

      def self.with_config(options={})
        self.config.merge!(options)
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
