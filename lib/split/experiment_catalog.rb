module Split
  class ExperimentCatalog
    # Return all experiments
    def self.all
      # Call compact to prevent nil experiments from being returned -- seems to happen during gem upgrades
      Split.redis.smembers(:experiments).map {|e| find(e)}.compact
    end

    # Return experiments without a winner (considered "active") first
    def self.all_active_first
      all.partition{|e| not e.winner}.map{|es| es.sort_by(&:name)}.flatten
    end

    def self.find(name)
      obj = nil
      if Split.redis.exists(name)
        obj = Experiment.new name
        obj.load_from_redis
      end
      obj
    end

    def self.find_or_create(label, *alternatives)
      experiment_name_with_version, goals = normalize_experiment(label)
      name = experiment_name_with_version.to_s.split(':')[0]

      exp = Experiment.new name, :alternatives => alternatives, :goals => goals
      exp.save
      exp
    end

    private

    def self.normalize_experiment(label)
      if Hash === label
        experiment_name = label.keys.first
        goals = label.values.first
      else
        experiment_name = label
        goals = []
      end
      return experiment_name, goals
    end

  end
end
