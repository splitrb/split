# frozen_string_literal: true
require 'split/zscore'

# TODO: - take out require and implement using file paths?

module Split
  class Alternative
    attr_accessor :name
    attr_accessor :experiment_name
    attr_accessor :weight

    include Zscore

    def initialize(name, experiment_name)
      @experiment_name = experiment_name
      if name.is_a?(Hash)
        @name = name.keys.first
        @weight = name.values.first
      else
        @name = name
        @weight = 1
      end
    end

    def to_s
      name
    end

    def ==(other)
      name == other&.name && experiment_name == other&.experiment_name
    end

    def goals
      experiment.goals
    end

    def scores
      return @scores if defined?(@scores)
      experiment_data = Split.configuration.experiments[experiment_name.to_s] || Split.configuration.experiments[experiment_name.to_sym]
      return (@scores = []) unless experiment_data
      @scores = experiment_data[:scores] || experiment_data['scores']
    end

    def p_winner(goal = nil)
      field = set_prob_field(goal)
      Split.redis.hget(key, field).to_f
    end

    def set_p_winner(prob, goal = nil)
      field = set_prob_field(goal)
      Split.redis.hset(key, field, prob.to_f)
    end

    def participant_count
      Split.redis.hget(key, 'participant_count').to_i
    end

    def participant_count=(count)
      Split.redis.hset(key, 'participant_count', count.to_i)
    end

    def completed_count(goal = nil)
      field = set_field(goal)
      Split.redis.hget(key, field).to_i
    end

    def all_completed_count
      if goals.empty?
        completed_count
      else
        goals.inject(completed_count) do |sum, g|
          sum + completed_count(g)
        end
      end
    end

    def score(score_name)
      return nil unless scores.include?(score_name)
      Split.redis.hget(key, "score:#{score_name}").to_i
    end

    def score_participant_count(score_name)
      return nil unless scores.include?(score_name)
      Split.redis.hget(key, "score_participant_count:#{score_name}").to_i
    end

    def unfinished_count
      participant_count - all_completed_count
    end

    def set_field(goal)
      field = 'completed_count'
      field += ':' + goal unless goal.nil?
      field
    end

    def set_prob_field(goal)
      field = 'p_winner'
      field += ':' + goal unless goal.nil?
      field
    end

    def set_completed_count(count, goal = nil)
      field = set_field(goal)
      Split.redis.hset(key, field, count.to_i)
    end

    def increment_participation
      Split.redis.hincrby key, 'participant_count', 1
    end

    def increment_completion(goal = nil)
      field = set_field(goal)
      Split.redis.hincrby(key, field, 1)
    end

    def increment_score(score_name, value = 1)
      return nil unless scores.include?(score_name)
      _, new_score = Split.redis.multi do
        Split.redis.hincrby(key, "score_participant_count:#{score_name}", 1)
        Split.redis.hincrby(key, "score:#{score_name}", value)
      end
      new_score
    end

    def control?
      experiment.control.name == name
    end

    def conversion_rate(goal = nil)
      return 0 if participant_count.zero?
      completed_count(goal).to_f / participant_count.to_f
    end

    def conversion_rate_score(score_name)
      par = participant_count
      sco = score_participant_count(score_name)
      return 0 if par.zero? || sco > par
      sco.to_f / par.to_f
    end

    def experiment
      return @experiment if defined?(@experiment)
      @experiment = Split::ExperimentCatalog.find(experiment_name)
    end

    def z_score(goal = nil)
      # p_a = Pa = proportion of users who converted within the experiment split (conversion rate)
      # p_c = Pc = proportion of users who converted within the control split (conversion rate)
      # n_a = Na = the number of impressions within the experiment split
      # n_c = Nc = the number of impressions within the control split

      control = experiment.control
      alternative = self

      return 'N/A' if control.name == alternative.name

      p_a = alternative.conversion_rate(goal)
      p_c = control.conversion_rate(goal)

      n_a = alternative.participant_count
      n_c = control.participant_count

      Split::Zscore.calculate(p_a, n_a, p_c, n_c)
    end

    def z_score_score(score_name)
      # p_a = Pa = proportion of users who converted within the experiment split (conversion rate)
      # p_c = Pc = proportion of users who converted within the control split (conversion rate)
      # n_a = Na = the number of impressions within the experiment split
      # n_c = Nc = the number of impressions within the control split

      control = experiment.control
      alternative = self

      return 'N/A' if control.name == alternative.name || alternative.conversion_rate_score(score_name).zero?

      p_a = alternative.conversion_rate_score(score_name)
      p_c = control.conversion_rate_score(score_name)

      n_a = alternative.participant_count
      n_c = control.participant_count

      Split::Zscore.calculate(p_a, n_a, p_c, n_c)
    end

    def save
      Split.redis.hsetnx key, 'participant_count', 0
      Split.redis.hsetnx key, 'completed_count', 0
      Split.redis.hsetnx key, 'p_winner', p_winner
    end

    def validate!
      return if @name.is_a?(String) || hash_with_correct_values?(@name)
      raise ArgumentError, 'Alternative must be a string'
    end

    def reset
      Split.redis.hmset key, 'participant_count', 0, 'completed_count', 0
      reset_goals_data
      reset_scores_data
    end

    def delete
      Split.redis.del(key)
    end

    def key
      "#{experiment_name}:#{name}"
    end

    private

    def reset_goals_data
      redis_args = []
      unless goals.empty?
        goals.each do |g|
          redis_args << "completed_count:#{g}"
          redis_args << 0
        end
      end
      Split.redis.hmset key, *redis_args unless redis_args.empty?
    end

    def reset_scores_data
      redis_args = []
      unless scores.empty?
        scores.each do |s|
          redis_args << "score:#{s}"
          redis_args << 0
          redis_args << "score_participant_count:#{s}"
          redis_args << 0
        end
      end
      Split.redis.hmset key, *redis_args unless redis_args.empty?
    end

    def hash_with_correct_values?(name)
      name.is_a?(Hash) && name.keys.first.is_a?(String) && Float(name.values.first)
    rescue
      false
    end
  end
end
