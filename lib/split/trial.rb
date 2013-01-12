module Split
  class Trial
    attr_accessor :experiment
    attr_writer :alternative

    def initialize(attrs = {})
      self.experiment = attrs[:experiment]  if !attrs[:experiment].nil?
      self.alternative = attrs[:alternative] if !attrs[:alternative].nil?
      self.alternative_name = attrs[:alternative_name] if !attrs[:alternative_name].nil?
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
      choose
      record!
    end
    
    def record!
      alternative.increment_participation
    end

    def choose
      if experiment.winner
        self.alternative = experiment.winner
      else
        self.alternative = experiment.next_alternative
      end
    end
    
    def alternative_name=(name)
      self.alternative= self.experiment.alternatives.find{|a| a.name == name }
    end
  end
end