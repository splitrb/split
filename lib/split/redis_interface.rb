# frozen_string_literal: true
module Split
  # Simplifies the interface to Redis.
  class RedisInterface
    def initialize
      self.redis = Split.redis
    end

    def persist_list(list_name, list_values)
      max_index = list_length(list_name) - 1
      list_values.each_with_index do |value, index|
        if index > max_index
          add_to_list(list_name, value)
        else
          set_list_index(list_name, index, value)
        end
      end
      make_list_length(list_name, list_values.length)
      list_values
    end

    def add_to_list(list_name, value)
      redis.rpush(list_name, value)
    end

    def set_list_index(list_name, index, value)
      redis.lset(list_name, index, value)
    end

    def list_length(list_name)
      redis.llen(list_name)
    end

    def remove_last_item_from_list(list_name)
      redis.rpop(list_name)
    end

    def make_list_length(list_name, new_length)
      redis.ltrim(list_name, 0, new_length - 1)
    end

    def add_to_set(set_name, value)
      redis.sadd(set_name, value) unless redis.sismember(set_name, value)
    end

    private

    attr_accessor :redis
  end
end
