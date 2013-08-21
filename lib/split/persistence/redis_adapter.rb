module Split
  module Persistence
    class RedisAdapter

      def initialize(context)
      end

      def [](field)
        Split.redis.hget(redis_key, field)
      end

      def []=(field, value)
        Split.redis.hset(redis_key, field, value)
      end

      def delete(field)
        Split.redis.hdel(redis_key, field)
      end

      def keys
        Split.redis.hkeys(redis_key)
      end

      def redis_key
        'persistence'
      end

    end
  end
end
