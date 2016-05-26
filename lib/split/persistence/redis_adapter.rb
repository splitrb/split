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
          @split_id = key_frag
          @redis_key = get_redis_key(key_frag)
        else
          raise "Please configure lookup_by"
        end
      end

      def split_id
        @split_id 
      end
      
      ####
      # set_values_in_batch and fetch_values_in_batch are class methods
      # for setting/fetching values in hashes in batch (in single HTTP request)
      ####
      def self.set_values_in_batch(split_ids_values_mapping, field)
        Split.redis.with do |conn|
          ## redis pipeline will execute the commands 
          # in batch (in single HTTP reuqest)
          conn.pipelined do
            split_ids_values_mapping.each do |split_id, value|
              key = get_redis_key(split_id)
              conn.hset(key, field, value)
            end
          end
        end
      end
      
      def self.fetch_values_in_batch(split_ids, field)
        keys = split_ids.map{|split_id| get_redis_key(split_id)}
        # redis pipeline will execute the commands 
        # in batch (in single HTTP reuqest)
        mapped_hashes = {}
        Split.redis.with do |conn|
          conn.pipelined do
            keys.each do |key|
              mapped_hashes[key] = conn.hget(key, field)
            end
          end
        end
        
        # we want to return hashes whose keys are split_id and 
        # values are the values of the corresponding field if exists.
        flattened_arr = mapped_hashes.map do |key, hash_future|
          hash = hash_future.value
          val = (hash.nil? || !(hash.is_a? Hash))? nil : hash[field]
          [get_split_id(key), val]
        end
        Hash[flattened_arr]
      end
      
      # this is the composition of key as opposed to get_split_id
      def self.get_redis_key(key_frag)
        "#{config[:namespace]}:#{key_frag}"
      end
      
      def get_redis_key(key_frag)
        self.class.get_redis_key(key_frag)
      end
      
      # this is the decomposition of key as opposed to get_redis_key
      def self.get_split_id(key)
        key.gsub("#{config[:namespace]}:", "")
      end
      
      def get_split_id(key)
        self.class.get_split_id(key)
      end

      def [](field)
        Split.redis.with do |conn|
          conn.hget(redis_key, field)
        end
      end
      
      def hmget(fields)
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
