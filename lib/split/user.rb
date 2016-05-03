module Split
  class User
    extend Forwardable
    def_delegators :@user, :keys, :[], :[]=, :delete
    attr_reader :user

    def initialize(context)
      @user = Split::Persistence.adapter.new(context)
    end

    def cleanup_old_experiments!
      user.keys.each do |key|
        experiment = ExperimentCatalog.find key_without_version(key)
        if experiment.nil? || experiment.has_winner? || experiment.start_time.nil?
          user.delete key
        end
      end
    end

    def max_experiments_reached?(experiment_key)
      !Split.configuration.allow_multiple_experiments &&
        keys_without_experiment(user.keys, experiment_key).length > 0
    end

    def cleanup_old_versions!(experiment)
      keys = user.keys.select { |k| k.match(Regexp.new(experiment.name)) }
      keys_without_experiment(keys, experiment.key).each { |key| user.delete(key) }
    end

    def active_experiments
      experiment_pairs = {}
      user.keys.each do |key|
        Metric.possible_experiments(key_without_version(key)).each do |experiment|
          if !experiment.has_winner?
            experiment_pairs[key_without_version(key)] = user[key]
          end
        end
      end
      experiment_pairs
    end

    private

    def keys_without_experiment(keys, experiment_key)
      keys.reject { |k| k.match(Regexp.new("^#{experiment_key}(:finished)?$")) }
    end

    def key_without_version(key)
      key.split(/\:\d(?!\:)/)[0]
    end
  end
end
