# frozen_string_literal: true
module Split
  class ExperimentCatalog
    # Return all experiments
    def self.all
      # Call compact to prevent nil experiments from being returned -- seems to happen during gem upgrades
      Split.redis.smembers(:experiments).map { |e| find(e) }.compact
    end

    # Return experiments without a winner (considered "active") first
    def self.all_active_first
      all.partition { |e| !e.winner }.map { |es| es.sort_by(&:name) }
    end

    def self.find(name)
      return nil unless Split.redis.sismember(:experiments, name)
      ::Split::Experiment.new(name).tap(&:load_from_redis)
    end

    def self.find_or_initialize(experiment_name, *_deprecated)
      ::Split::Experiment.new(experiment_name)
    end

    def self.find_or_create(experiment_name, *_deprecated)
      experiment = find_or_initialize(experiment_name)
      experiment.save
    end
  end
end
