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
          Split::Experiment.find(experiment_name)
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

    def self.possible_experiments(metric_name)
      experiments = []
      metric  = Split::Metric.find(metric_name)
      if metric
        experiments << metric.experiments
      end
      experiment = Split::Experiment.find(metric_name)
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
  end
end