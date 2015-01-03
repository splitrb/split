require 'split/zscore'

# TODO - take out require and implement using file paths?

module Split
  class Alternative
    attr_accessor :name
    attr_accessor :experiment_name
    attr_accessor :weight

    include Zscore

    def initialize(name, experiment_name)
      @experiment_name = experiment_name
      if Hash === name
        @name = name.keys.first
        @weight = name.values.first
      else
        @name = name
        @weight = 1
      end
      p_winner = 0.0
    end

    def to_s
      name
    end

    def goals
      self.experiment.goals
    end

    def p_winner(goal = nil)
      field = set_prob_field(goal)
      @p_winner = Split.redis.hget(key, field).to_f
      return @p_winner
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

    def unfinished_count
      participant_count - all_completed_count
    end

    def set_field(goal)
      field = "completed_count"
      field += ":" + goal unless goal.nil?
      return field
    end

    def set_prob_field(goal)
      field = "p_winner"
      field += ":" + goal unless goal.nil?
      return field
    end

    def set_completed_count (count, goal = nil)
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

    def control?
      experiment.control.name == self.name
    end

    def conversion_rate(goal = nil)
      return 0 if participant_count.zero?
      (completed_count(goal).to_f)/participant_count.to_f
    end

    def experiment
      Split::ExperimentCatalog.find(experiment_name)
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

      z_score = Split::Zscore.calculate(p_a, n_a, p_c, n_c)
    end

    def save
      Split.redis.hsetnx key, 'participant_count', 0
      Split.redis.hsetnx key, 'completed_count', 0
      Split.redis.hsetnx key, 'p_winner', p_winner
    end

    def validate!
      unless String === @name || hash_with_correct_values?(@name)
        raise ArgumentError, 'Alternative must be a string'
      end
    end

    def reset
      Split.redis.hmset key, 'participant_count', 0, 'completed_count', 0
      unless goals.empty?
        goals.each do |g|
          field = "completed_count:#{g}"
          Split.redis.hset key, field, 0
        end
      end
    end

    def delete
      Split.redis.del(key)
    end

    private

    def hash_with_correct_values?(name)
      Hash === name && String === name.keys.first && Float(name.values.first) rescue false
    end

    def key
      "#{experiment_name}:#{name}"
    end
  end
end
