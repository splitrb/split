module Split
  class ScoresCollection
    def initialize(experiment_name, scores = nil)
      @experiment_name = experiment_name
      @scores = scores
    end

    def load_from_configuration
      scores = Split.configuration.experiment_for(@experiment_name)&.[](:scores)

      if scores.nil?
        []
      else
        scores.flatten
      end
    end

    def validate!
      return true if @scores.nil?
      raise ArgumentError, 'Scores must be an array' unless @scores.is_a? Array
      @scores.each do |score|
        raise ArgumentError, 'Score muse be a string' unless score.is_a? String
      end
    end
  end
end
