# frozen_string_literal: true

module Split
  class ExperimentCatalog
    # Return all experiments
    def self.all
      Split::Experiment.find_many(experiment_names)
    end

    # Return experiments without a winner (considered "active") first
    def self.all_active_first
      Split::Experiment.find_many(all_active_first_names)
    end

    def self.all_active_first_names
      names = experiment_names
      return names if names.empty?

      winners = Split.redis.hgetall(:experiment_winner)
      active, finished = names.partition { |name| !winners.key?(name) }
      active.sort + finished.sort
    end

    def self.experiment_names
      Split.redis.smembers(:experiments)
    end

    def self.find(name)
      Experiment.find(name)
    end

    def self.find_or_initialize(metric_descriptor, control = nil, *alternatives)
      # Check if array is passed to ab_test
      # e.g. ab_test('name', ['Alt 1', 'Alt 2', 'Alt 3'])
      if control.is_a?(Array) && alternatives.length.zero?
        control, alternatives = control.first, control[1..-1]
      end

      experiment_name_with_version, goals = normalize_experiment(metric_descriptor)
      experiment_name = experiment_name_with_version.to_s.split(":")[0]
      Split::Experiment.new(experiment_name,
          alternatives: [control].compact + alternatives, goals: goals)
    end

    def self.find_or_create(metric_descriptor, control = nil, *alternatives)
      experiment = find_or_initialize(metric_descriptor, control, *alternatives)
      experiment.save
    end

    def self.normalize_experiment(metric_descriptor)
      if Hash === metric_descriptor
        experiment_name = metric_descriptor.keys.first
        goals = Array(metric_descriptor.values.first)
      else
        experiment_name = metric_descriptor
        goals = []
      end
      return experiment_name, goals
    end
    private_class_method :normalize_experiment
  end
end
