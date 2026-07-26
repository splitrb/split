# frozen_string_literal: true

require "forwardable"

module Split
  class User
    extend Forwardable
    def_delegators :@user, :keys, :[], :[]=, :delete
    attr_reader :user

    def initialize(context, adapter = nil)
      @user = adapter || Split::Persistence.adapter.new(context)
      @cleaned_up = false
    end

    def cleanup_old_experiments!
      return if @cleaned_up
      keys = keys_without_finished(user.keys)
      names = keys.map { |key| key_without_version(key) }

      unless names.empty?
        winners, start_times = Split.redis.pipelined do |pipe|
          pipe.hmget(:experiment_winner, *names)
          pipe.hmget(:experiment_start_times, *names)
        end

        keys.each_with_index do |key, index|
          has_winner = !winners[index].nil?
          not_started = start_times[index].nil?
          if has_winner || not_started
            user.delete key
            user.delete Experiment.finished_key(key)
          end
        end
      end

      @cleaned_up = true
    end

    def max_experiments_reached?(experiment_key)
      if Split.configuration.allow_multiple_experiments == "control"
        experiments = active_experiments
        experiment_key_without_version = key_without_version(experiment_key)
        count_control = experiments.count { |k, v| k == experiment_key_without_version || v == "control" }
        experiments.size > count_control
      else
        !Split.configuration.allow_multiple_experiments &&
          keys_without_experiment(user.keys, experiment_key).length > 0
      end
    end

    def cleanup_old_versions!(experiment)
      keys = user.keys.select { |k| key_without_version(k) == experiment.name }
      keys_without_experiment(keys, experiment.key).each { |key| user.delete(key) }
    end

    def active_experiments
      experiments_by_key = keys_without_finished(user.keys).each_with_object({}) do |key, memo|
        memo[key] = Metric.possible_experiments(key_without_version(key))
      end

      names = experiments_by_key.values.flatten.map(&:name).uniq
      winners = names.empty? ? {} : names.zip(Split.redis.hmget(:experiment_winner, *names)).to_h

      experiment_pairs = {}
      experiments_by_key.each do |key, experiments|
        experiments.each do |experiment|
          unless winners[experiment.name]
            experiment_pairs[key_without_version(key)] = user[key]
          end
        end
      end
      experiment_pairs
    end

    def self.find(user_id, adapter)
      adapter = adapter.is_a?(Symbol) ? Split::Persistence::ADAPTERS[adapter] : adapter

      if adapter.respond_to?(:find)
        User.new(nil, adapter.find(user_id))
      else
        nil
      end
    end

    private
      def keys_without_experiment(keys, experiment_key)
        keys.reject { |k| k.match(Regexp.new("^#{experiment_key}(:finished)?$")) }
      end

      def keys_without_finished(keys)
        keys.reject { |k| k.include?(":finished") }
      end

      def key_without_version(key)
        key.split(/\:\d(?!\:)/)[0]
      end
  end
end
