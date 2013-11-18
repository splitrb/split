module Split
  class Alternative
    attr_accessor :name
    attr_accessor :experiment_name
    attr_accessor :weight

    include Math

    def initialize(name, experiment_name)
      @experiment_name = experiment_name
      if Hash === name
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

    def goals
      self.experiment.goals
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
      Split::Experiment.find(experiment_name)
    end

    def z_score(goal = nil)
      # p_a = Pa = proportion of users who converted within the experiment split (conversion rate)
      # p_c = Pc = proportion of users who converted within the control split (conversion rate)
      # n_a = Na = the number of impressions within the experiment split
      # n_c = Nc = the number of impressions within the control split
      # s_a = SEa = standard error of p_a, the estiamte of the mean
      # s_c = SEc = standard error of p_c, the estimate of the control
      # s_p = SEp = standard error of p_a - p_c, assuming a pooled variance
      # s_unp = SEunp = standard error of p_a - p_c, assuming unpooled variance

      control = experiment.control

      alternative = self

      return 'N/A' if control.name == alternative.name

      p_a = alternative.conversion_rate(goal).to_f
      p_c = control.conversion_rate(goal).to_f

      n_a = alternative.participant_count.to_f
      n_c = control.participant_count.to_f

      # Perform checks on data to make sure we can validly run our confidence tests
      if n_a < 30 || n_c < 30
        error = "Needs 30+ participants."
        return error
      elsif p_a * n_a < 5 || p_c * n_c < 5
        error = "Needs 5+ conversions."
        return error
      end

      # Formula for standard error: root(pq/n) = root(p(1-p)/n)
      s_a = Math.sqrt((p_a)*(1-p_a)/(n_a))
      s_c = Math.sqrt((p_c)*(1-p_c)/(n_c))

      # Formula for pooled error of the difference of the means: root(π*(1-π)*(1/na+1/nc)
      # π = (xa + xc) / (na + nc)
      pi = (p_a*n_a + p_c*n_c)/(n_a + n_c) 
      s_p = Math.sqrt(pi*(1-pi)*(1/n_a + 1/n_c))

      # Formula for unpooled error of the difference of the means: root(sa**2/na + sc**2/nc)
      s_unp = Math.sqrt(s_a**2 + s_c**2)

      # Boolean variable decides whether we can pool our variances
      pooled = s_a/s_c < 2 && s_c/s_a < 2

      # Assign standard error either the pooled or unpooled variance
      se = pooled ? s_p : s_unp

      # Calculate z-score
      z_score = (p_a - p_c)/(se)

      return z_score

    end

    def save
      Split.redis.hsetnx key, 'participant_count', 0
      Split.redis.hsetnx key, 'completed_count', 0
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
