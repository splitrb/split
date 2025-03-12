# frozen_string_literal: true
require 'forwardable'

module Split
  class User
    extend Forwardable
    def_delegators :@user, :keys, :[], :[]=, :delete
    attr_reader :user

    def initialize(context, adapter=nil)
      @user = adapter || Split::Persistence.adapter.new(context)
      @cleaned_up = false
    end

    def cleanup_old_experiments!
      return if @cleaned_up
      exp_to_delete = {}

      user.keys.each do |key|
        exp_name = experiment_name(key)

        unless exp_to_delete.include?(exp_name)
          experiment = ExperimentCatalog.find exp_name
          exp_to_delete[exp_name] = experiment.nil? || experiment.has_winner? || experiment.start_time.nil?
        end

        if exp_to_delete[exp_name]
          user.delete key
        end
      end
      @cleaned_up = true
    end

    def max_experiments_reached?(experiment_key)
      if Split.configuration.allow_multiple_experiments == 'control'
        experiments = active_experiments
        experiment_key_without_version = key_without_version(experiment_key)
        count_control = experiments.count {|k,v| k == experiment_key_without_version || v == 'control'}
        experiments.size > count_control
      else
        !Split.configuration.allow_multiple_experiments &&
          keys_without_experiment(user.keys, experiment_key).length > 0
      end
    end

    def cleanup_old_versions!(experiment)
      keys = user.keys.select { |k| k.match(Regexp.new("^#{experiment.name}(:|$)")) }
      keys_without_experiment(keys, experiment.key).each { |key| user.delete(key) }
    end

    def active_experiments
      experiment_pairs = {}
      experiment_keys(user.keys).each do |key|
        Metric.possible_experiments(key_without_version(key)).each do |experiment|
          if !experiment.has_winner?
            experiment_pairs[key_without_version(key)] = user[key]
          end
        end
      end
      experiment_pairs
    end

    def alternative_key_for_experiment(experiment)
      user_experiment_key = first_field_from_all_versions(experiment)
      #default to current experiment key when one isn't found
      user_experiment_key || experiment.key
    end

    def all_fields_for_experiment_key(experiment_key)
      user.keys - keys_without_experiment(user.keys, experiment_key)
    end

    def first_field_from_all_versions(experiment, exp_attribute = "")
      keys = user.keys
      exp_attribute = ":#{exp_attribute}" unless exp_attribute.empty?
      result = nil

      if keys.include?(experiment.name + exp_attribute)
        result = experiment.name + exp_attribute
      else
        experiment.version.times do |version_number|
          key = "#{experiment.name}:#{version_number+1}" + exp_attribute
          if keys.include?(key)
            result = key
            break
          end
        end
      end

      result
    end

    private
    def experiment_name(key)
      key.partition(':').first
    end

    def keys_without_experiment(keys, experiment_key)
      if experiment_key.include?(':')
        sub_keys = keys.reject { |k| k == experiment_key }
        sub_keys.reject do |k|
          sub_str = k.partition(':').last

          k.match(Regexp.new("^#{experiment_key}:")) && sub_str.scan(Regexp.new("\\D")).any?
        end
      else
        keys.select do |k|
          k.match(Regexp.new("^#{experiment_key}:\\d+(:|$)")) ||
            k.partition(':').first != experiment_key
        end
      end
    end

    def experiment_keys(keys)
      keys.reject do |k|
        sub_str = k.partition(':').last
        sub_str.scan(Regexp.new("\\D")).any?
      end
    end

    def key_without_version(key)
      key.split(/\:\d(?!\:)/)[0]
    end
  end
end