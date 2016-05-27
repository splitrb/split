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
          conn.pipelined do
            split_ids_values_mapping.keys.each_slice(Split.configuration.redis_query_batch_size).each_with_index do |slice, slice_index|
              queries = []
              key_subarr = []
              slice.each_with_index do |split_id, index|
                key = get_redis_key(split_id)
                value = split_ids_values_mapping[split_id]
                queries << "redis.call('hset',KEYS[#{index+1}],ARGV[1],'#{value}')"
                key_subarr << key
              end

              script = queries.join("\n")
              conn.eval(script, key_subarr, [field])
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
      def self.fetch_values_in_batch(split_ids, field)
        keys = split_ids.map{|split_id| get_redis_key(split_id)}
        # redis pipeline will send requests without waiting for 
        # each response
        arrays_of_alternatives = []
        Split.redis.with do |conn|
          conn.pipelined do
            keys.each_slice(Split.configuration.redis_query_batch_size).each_with_index do |slice, slice_index|
              # construct lua script that runs multiple HGETs
              # note that Lua array by convention is 1-indexed so we
              # add 1 to the index in Lua. The returned Ruby array is 
              # converted to zero-indexed. 
              queries = []
              key_subarr = []
              queries << "local r={}"
              slice.each_with_index do |key, index|
                lua_index = index + 1
                queries << "r[#{lua_index}]=redis.pcall('HGET', KEYS[#{lua_index}], ARGV[1])"
                key_subarr << key
              end
              queries << "return r"
              # this is a faster way to concatenate a lot of strings at once
              script = queries.join("\n")
              arrays_of_alternatives[slice_index] = conn.eval(script, key_subarr, [field])
            end
          end
        end
        
        # we want to return hashes whose keys are split_id and 
        # values are the values of the corresponding field if exists.
        mapped_hashes = {}
        keys.each_slice(Split.configuration.redis_query_batch_size).each_with_index do |slice, slice_index|
          slice.each_with_index do |key, index|
            alternative_name = arrays_of_alternatives[slice_index].value[index]
            mapped_hashes[get_split_id(key)] = alternative_name
          end
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
