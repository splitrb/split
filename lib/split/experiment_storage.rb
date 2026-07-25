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

        alts = alts.keys if alts.is_a?(Hash)
        alts.flatten
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

      def load!
        raw_config, raw_alternatives, raw_metadata, raw_goals = redis.pipelined do |pipe|
          pipe.hgetall(experiment_config_key)
          pipe.lrange(@name, 0, -1)
          pipe.get(metadata_key)
          pipe.lrange(goals_key, 0, -1)
        end
        config = raw_config.transform_keys(&:to_sym)

        {
          resettable: config[:resettable],
          algorithm: config[:algorithm],
          alternatives: build_alternatives(raw_alternatives),
          goals: raw_goals,
          metadata: parse_metadata(raw_metadata)
        }
      end

      def experiment_config_key
        "experiment_configurations/#{@name}"
      end

      def metadata_key
        "#{name}:metadata"
      end

      def goals_key
        "#{name}:goals"
      end

      private
        def redis
          Split.redis
        end

        def build_alternatives(raw_alternatives)
          raw_alternatives.map do |alt|
            alt = begin
                    JSON.parse(alt)
                  rescue
                    alt
                  end
            Split::Alternative.new(alt, @name)
          end
        end

        def parse_metadata(raw_metadata)
          JSON.parse(raw_metadata) unless raw_metadata.nil?
        end
    end
  end
end
