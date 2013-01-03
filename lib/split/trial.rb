module Split
  class Trial
    attr_accessor :experiment
    attr_writer   :alternative

    def initialize(attrs = {})
      attrs.each do |key,value|
        if self.respond_to?("#{key}=")
          self.send("#{key}=", value)
        end
      end
    end

    def alternative
      @alternative ||= select_alternative
    end

    def complete!
      alternative.increment_completion
    end

    def alternative_name=(name)
      self.alternative= experiment.alternatives.find{|a| a.name == name }
    end

    private

    def select_alternative
      if experiment.winner
        experiment.winner
      else
        alt = experiment.next_alternative
        alt.increment_participation
        alt
      end
    end
  end
end