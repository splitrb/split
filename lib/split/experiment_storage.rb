# frozen_string_literal: true

module Split
  class ExperimentStorage
    class BaseStorage
      attr_accessor :name

      def initialize(name)
        @name = name
      end

      def load
        @data ||= load!
      end

      def load!
        experiment_config = load_experiment
        alternatives = load_alternatives
        metadata = load_metadata
        goals = load_goals

        {
          resettable: experiment_config[:resettable],
          algorithm: experiment_config[:algorithm],
          alternatives: alternatives,
          goals: goals,
          metadata: metadata
        }
      end

      def exists?
        raise "implement"
      end

      def load_alternatives
        raise "implement"
      end

      def load_metadata
        raise "implement"
      end

      def load_goals
        raise "implement"
      end

      def load_experiment
        raise "implement"
      end
    end

    class ConfigStorage < BaseStorage
      def exists?
        !!Split.configuration.experiment_for(@name)
      end

      def load_alternatives
        alts = Split.configuration.experiment_for(@name)[:alternatives]
        raise ArgumentError, "Experiment configuration is missing :alternatives array" unless alts
        if alts.is_a?(Hash)
          alts.keys
        else
          alts.flatten
        end
      end

      def load_metadata
        Split.configuration.experiment_for(@name)[:metadata]
      end

      def load_goals
        Split::GoalsCollection.new(@name).load_from_configuration
      end

      def load_experiment
        Split.configuration.experiment_for(@name)
      end
    end

    class RedisStorage < BaseStorage
      def exists?
        redis.exists?(@name)
      end

      def load_alternatives
        alternatives = redis.lrange(@name, 0, -1)
        alternatives.map do |alt|
          alt = begin
                  JSON.parse(alt)
                rescue
                  alt
                end
          Split::Alternative.new(alt, @name)
        end
      end

      def load_metadata
        meta = redis.get(metadata_key)
        JSON.parse(meta) unless meta.nil?
      end

      def load_goals
        Split::GoalsCollection.new(@name).load_from_redis
      end

      def load_experiment
        redis.hgetall(experiment_config_key).transform_keys(&:to_sym)
      end

      def experiment_config_key
        "experiment_configurations/#{@name}"
      end

      def metadata_key
        "#{name}:metadata"
      end

      private
        def redis
          Split.redis
        end
    end
  end
end
