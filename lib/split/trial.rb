module Split
  class Trial
    attr_accessor :experiment
    attr_writer :alternative

    def initialize(attrs = {})
      attrs.each do |key,value|
        if self.respond_to?("#{key}=")
          self.send("#{key}=", value)
        end
      end
    end

    def alternative
      @alternative ||=  if experiment.winner
                          experiment.winner
                        end
    end

    def complete!
      alternative.increment_completion if alternative
    end

    def choose!
      self.alternative = choose
      self.alternative.increment_participation      
    end
    
    def record!
      self.alternative.increment_participation
    end

    def alternative_name=(name)
      self.alternative= experiment.alternatives.find{|a| a.name == name }
    end

    def choose
      if experiment.winner
        experiment.winner
      else
        alt = experiment.next_alternative
        alt
      end
    end
  end
end