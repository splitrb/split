# frozen_string_literal: true

module Split
  # Simplifies the interface to Redis.
  class RedisInterface
    def initialize
      self.redis = Split.redis
    end

    def persist_list(list_name, list_values)
      if list_values.length > 0
        redis.multi do |multi|
          tmp_list = "#{list_name}_tmp"
          multi.rpush(tmp_list, list_values)
          multi.rename(tmp_list, list_name)
        end
      end

      list_values
    end

    def add_to_set(set_name, value)
      redis.sadd(set_name, value)
    end

    private
      attr_accessor :redis
  end
end
