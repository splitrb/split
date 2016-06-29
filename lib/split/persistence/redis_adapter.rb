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
        split_ids = split_ids_values_mapping.keys
        # use 5 threads to run this in parallel
        size_per_thread = [(split_ids.count / 5), 1].max
        Parallel.each(split_ids.each_slice(size_per_thread).to_a, in_threads:5) do |slice_per_thread|
          # slice up the workload further down to pipeline sizes
          slice_per_thread.each_slice(Split.configuration.pipeline_size).each do |slice|
            Split.redis.with do |conn|
              conn.pipelined do
                slice.each do |split_id|
                  conn.hset(get_redis_key(split_id), field, split_ids_values_mapping[split_id])
                end
              end
            end
          end
        end
      end
      
      ##NOTE: Our redis storage is namespaced, i.e. it prepends 'split:touchofmodern'
      # to all the keys. For example an exemplary key is 'split:touchofmodern:persistence:65a641f4-06da-4599-83f4-f84f88cb30f4'.
      # This gets tricky when calling redis.call() in Lua scripting. In Lua scripting, you can either 
      # do inline arguments such as redis.call('hget', yourKey, yourField) or append keys and arguments such as 
      # conn.eval("redis.call('hget', KEYS[1], ARGV[1])", [yourKey], [yourField]).
      # As you can see, the first array in the arguments is an array of keys. 
      # The second array in the arguments is an array of fields. 
      # Redis library will smartly prepend your keys with the namespace. 
      # However if you do it in inline fashion like conn.eval("redis.call('hget', 'persistence:65a641f4-06da-4599-83f4-f84f88cb30f4', 'yourField')",
      # it won't prepend the namespace to the keys which causes you problem.
      #
      # Simply put, append keys as a key array and append fields as an argv array. Don't use inline.
      # This function has evolved over several versions to enhance the performance. 
      def self.fetch_values_in_batch(split_ids, field)
        mapped_hashes = Hash[split_ids.map{|split_id| [split_id, nil]}]
        # use 5 threads to run this in parallel
        size_per_thread = [(split_ids.count / 5), 1].max
        Parallel.each(split_ids.each_slice(size_per_thread).to_a, in_threads:5) do |slice_per_thread|
          # slice up the workload further down to pipeline sizes
          slice_per_thread.each_slice(Split.configuration.pipeline_size).each do |slice|
            Split.redis.with do |conn|
              conn.pipelined do
                slice.each do |split_id|
                  mapped_hashes[split_id] = conn.hget(get_redis_key(split_id), field)
                end
              end
            end
          end
        end
        mapped_hashes.each do |split_id, future|
          mapped_hashes[split_id] = future.value unless future == nil
        end
        mapped_hashes
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
