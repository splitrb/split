module Split
  class ScoresCollection
    def initialize(experiment_name, scores = nil)
      @experiment_name = experiment_name
      @scores = scores
    end

    def load_from_redis
      Split.redis.lrange(scores_key, 0, -1)
    end

    def load_from_configuration
      scores = Split.configuration.experiment_for(@experiment_name)[:scores]

      if scores.nil?
        []
      else
        scores.flatten
      end
    end

    def save
      return false if @scores.nil?
      RedisInterface.new.persist_list(scores_key, @scores)
    end

    def validate!
      return true if @scores.nil?
      raise ArgumentError, 'Scores must be an array' unless @scores.is_a? Array
      @scores.each do |score|
        raise ArgumentError, 'Score muse be a string' unless score.is_a? String
      end
    end

    def delete
      Split.redis.del(scores_key)
    end

    private

    def scores_key
      "#{@experiment_name}:scores"
    end
  end
end
