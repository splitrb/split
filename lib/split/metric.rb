module Split
  class Metric
    attr_accessor :name
    attr_accessor :experiments

    def initialize(attrs = {})
      attrs.each do |key,value|
        if self.respond_to?("#{key}=")
          self.send("#{key}=", value)
        end
      end
    end

    def self.load_from_redis(name)
      metric = Split.redis.hget(:metrics, name)
      if metric
        experiment_names = metric.split(',')

        experiments = experiment_names.collect do |experiment_name|
          Split::ExperimentCatalog.find(experiment_name)
        end

        Split::Metric.new(:name => name, :experiments => experiments)
      else
        nil
      end
    end

    def self.load_from_configuration(name)
      metrics = Split.configuration.metrics
      if metrics && metrics[name]
        Split::Metric.new(:experiments => metrics[name], :name => name)
      else
        nil
      end
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
      redis_metrics = Split.redis.hgetall(:metrics).collect do |key, value|
        find(key)
      end
      configuration_metrics = Split.configuration.metrics.collect do |key, value|
        new(name: key, experiments: value)
      end
      redis_metrics | configuration_metrics
    end

    def self.possible_experiments(metric_name)
      experiments = []
      metric  = Split::Metric.find(metric_name)
      if metric
        experiments << metric.experiments
      end
      experiment = Split::ExperimentCatalog.find(metric_name)
      if experiment
        experiments << experiment
      end
      experiments.flatten
    end

    def save
      Split.redis.hset(:metrics, name, experiments.map(&:name).join(','))
    end

    def complete!
      experiments.each do |experiment|
        experiment.complete!
      end
    end

    def self.normalize_metric(label)
      if Hash === label
        metric_name = label.keys.first
        goals = label.values.first
      else
        metric_name = label
        goals = []
      end
      return metric_name, goals
    end
    private_class_method :normalize_metric

  end
end
