module Split
  class User
    extend Forwardable
    def_delegators :@user, :keys, :[], :multi_get, :[]=, :delete
    attr_reader :user

    def initialize(context, adapter = nil)
      @user = adapter || Split::Persistence.adapter.new(context)
    end

    def cleanup_old_experiments!
      keys_without_finished(user.keys).each do |key|
        experiment = ExperimentCatalog.find key_without_version(key)
        next unless experiment.nil? || experiment.has_winner? || experiment.start_time.nil?

        deleted_keys = [key, Experiment.finished_key(key)]
        score_names = ExperimentCatalog.find_or_initialize(key_without_version(key)).scores
        score_names.each do |score_name|
          deleted_keys << Experiment.scored_key(key, score_name)
        end
        user.delete(*deleted_keys)
      end
    end

    def max_experiments_reached?(experiment_key)
      if Split.configuration.allow_multiple_experiments == 'control'
        experiments = active_experiments
        count_control = experiments.count { |k, v| k == experiment_key || v == 'control' }
        experiments.size > count_control
      else
        !Split.configuration.allow_multiple_experiments &&
          !keys_without_experiment(user.keys, experiment_key).empty?
      end
    end

    def cleanup_old_versions!(experiment)
      keys = user.keys.select { |k| k.match(Regexp.new(experiment.name)) }
      deleted_keys = []
      keys_without_experiment(keys, experiment.key).each { |key| deleted_keys << key }
      user.delete(*deleted_keys) unless deleted_keys.empty?
    end

    def active_experiments
      experiment_pairs = {}
      user.keys.each do |key|
        Metric.possible_experiments(key_without_version(key)).each do |experiment|
          unless experiment.has_winner?
            experiment_pairs[key_without_version(key)] = user[key]
          end
        end
      end
      experiment_pairs
    end

    private

    def keys_without_experiment(keys, experiment_key)
      keys.reject { |k| k.match(Regexp.new("^#{experiment_key}(:finished|:scored:.+)?$")) }
    end

    def keys_without_finished(keys)
      keys.reject { |k| k.include?(':finished') || k.include?(':scored:') }
    end

    def key_without_version(key)
      key.split(/\:\d(?!\:)/)[0]
    end
  end
end
