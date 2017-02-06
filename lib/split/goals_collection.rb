module Split
  class GoalsCollection
    def initialize(experiment_name, goals = nil)
      @experiment_name = experiment_name
      @goals = goals
    end

    def load_from_configuration
      goals = Split.configuration.experiment_for(@experiment_name)&.[](:goals)

      if goals.nil?
        []
      else
        goals.flatten
      end
    end

    def validate!
      return if @goals.nil? || @goals.is_a?(Array)
      raise ArgumentError, 'Goals must be an array'
    end
  end
end
