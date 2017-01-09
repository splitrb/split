# frozen_string_literal: true
module Split
  class Metric
    attr_accessor :name
    attr_accessor :experiments

    def initialize(attrs = {})
      attrs.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
      end
    end

    def self.load_from_redis(name)
      metric = Split.redis.hget(:metrics, name)
      return unless metric

      experiment_names = metric.split(',')
      experiments = experiment_names.collect do |experiment_name|
        Split::ExperimentCatalog.find(experiment_name)
      end

      Split::Metric.new(name: name, experiments: experiments)
    end

    def self.load_from_configuration(name)
      metrics = Split.configuration.metrics
      return unless metrics && metrics[name]
      Split::Metric.new(experiments: metrics[name], name: name)
    end

    def self.find(name)
      name = name.intern if name.is_a?(String)
      metric = load_from_configuration(name)
      metric = load_from_redis(name) if metric.nil?
      metric
    end

    def self.find_or_create(attrs)
      metric = find(attrs[:name])
      unless metric
        metric = new(attrs)
        metric.save
      end
      metric
    end

    def self.all
      redis_metrics = Split.redis.hgetall(:metrics).collect do |key, _value|
        find(key)
      end
      configuration_metrics = Split.configuration.metrics.collect do |key, value|
        new(name: key, experiments: value)
      end
      redis_metrics | configuration_metrics
    end

    def self.possible_experiments(metric_name)
      experiments = []
      metric = Split::Metric.find(metric_name)
      experiments << metric.experiments if metric
      experiment = Split::ExperimentCatalog.find(metric_name)
      experiments << experiment if experiment
      experiments.flatten
    end

    def save
      Split.redis.hset(:metrics, name, experiments.map(&:name).join(','))
    end

    def complete!
      experiments.each(&:complete!)
    end

    def self.normalize_metric(label)
      if label.is_a?(Hash)
        metric_name = label.keys.first
        goals = label.values.first
      else
        metric_name = label
        goals = []
      end
      [metric_name, goals]
    end
    private_class_method :normalize_metric
  end
end
