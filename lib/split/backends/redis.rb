require 'redis/namespace'
module Split
  module Backends
    module Redis
      # Accepts:
      #   1. A 'hostname:port' string
      #   2. A 'hostname:port:db' string (to select the Redis db)
      #   3. A 'hostname:port/namespace' string (to set the Redis namespace)
      #   4. A redis URL string 'redis://host:port'
      #   5. An instance of `Redis`, `Redis::Client`, `Redis::DistRedis`,
      #      or `Redis::Namespace`.
      def server=(server)
        if server.respond_to? :split
          if server["redis://"]
            redis = ::Redis.connect(:url => server, :thread_safe => true)
          else
            server, namespace = server.split('/', 2)
            host, port, db = server.split(':')
            redis = ::Redis.new(:host => host, :port => port,
              :thread_safe => true, :db => db)
          end
          namespace ||= :split

          @server = ::Redis::Namespace.new(namespace, :redis => redis)
        elsif server.respond_to? :namespace=
            @server = server
        else
          @server = ::Redis::Namespace.new(:split, :redis => server)
        end
      end

      # Returns the current Redis connection. If none has been created, will
      # create a new one.
      def server
        return @server if @server
        self.server = 'localhost:6379'
        self.server
      end
      
      def clean
        server.flushall
      end
      
      def exists?(experiment_key)
        self.server.exists(experiment_key)
      end

      def save(experiment_name, alternatives, time)
        self.server.sadd(:experiments, experiment_name)
        self.server.hset(:experiment_start_times, experiment_name, time)
        alternatives.reverse.each do |a|
          self.server.lpush(experiment_name, a.name)
          self.server.hsetnx "#{experiment_name}:#{a.name}", 'participant_count', 0
          self.server.hsetnx "#{experiment_name}:#{a.name}", 'completed_count', 0
        end
      end

      def alternatives(experiment_name)
        case self.server.type(experiment_name)
        when 'set' # convert legacy sets to lists
          alts = self.server.smembers(experiment_name)
          self.server.delete(experiment_name)
          alts.reverse.each {|a| self.server.lpush(experiment_name, a) }
          self.server.lrange(experiment_name, 0, -1)
        else
          self.server.lrange(experiment_name, 0, -1)
        end
      end
      
      def alternative_participant_count(experiment_name, alternative)
        self.server.hget("#{experiment_name}:#{alternative}", 'participant_count').to_i
      end

      def alternative_completed_count(experiment_name, alternative)
        self.server.hget("#{experiment_name}:#{alternative}", 'completed_count').to_i
      end

      def start_time(experiment_name)
        t = self.server.hget(:experiment_start_times, experiment_name)
        Time.parse(t) if t
      end

      def all_experiments
        Array(self.server.smembers(:experiments))
      end

      def version(experiment_name)
        self.server.get("#{experiment_name.to_s}:version").to_i
      end

      def winner(experiment_name)
        self.server.hget(:experiment_winner, experiment_name)
      end

      def alternative_names(experiment_name)
        self.server.lrange(experiment_name, 0, -1)
      end

      def increment_version(experiment_name)
        self.server.incr("#{experiment_name}:version")
      end

      def set_winner(experiment_name, winner)
        self.server.hset(:experiment_winner, experiment_name, winner.to_s)
      end

      def reset_winner(experiment_name)
        self.server.hdel(:experiment_winner, experiment_name)
      end

      def delete(experiment_key)
        self.server.del(experiment_key)
        self.server.srem(:experiments, experiment_key)
      end

      def reset(experiment_name, alternative_name)
        self.server.hmset "#{experiment_name}:#{alternative_name}", 'participant_count', 0, 'completed_count', 0
      end

      def incr_alternative_participant_count(experiment_name, alternative)
        self.server.hincrby "#{experiment_name}:#{alternative}", 'participant_count', 1
      end

      def incr_alternative_completed_count(experiment_name, alternative)
        self.server.hincrby "#{experiment_name}:#{alternative}", 'completed_count', 1
      end

      def hsetnx(key, attribute, value)
        self.server.hsetnx  key, attribute, value
      end

      def srem(key, attribute)
        self.server.srem(key, attribute)
      end
    end
  end
end