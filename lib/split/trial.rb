module Split
  class Trial
    attr_accessor :experiment
    attr_accessor :goals
    attr_accessor :value
    attr_accessor :user
    
    def initialize(attrs = {})
      self.experiment = attrs[:experiment]  if !attrs[:experiment].nil?
      self.goals = attrs[:goals].nil? ? [] : attrs[:goals]
      self.value = attrs[:value] if !attrs[:value].nil?
      self.user = attrs[:user] if !attrs[:user].nil?
    end

    def alternative
      @alternative ||=  if experiment.has_winner?
                          experiment.winner
                        else
                          choose
                        end
    end

    def complete!
      if alternative
        if self.goals.empty?
          if !experiment.finished?(split_id)
            alternative.increment_unique_completion
            experiment.finish!(split_id)
          end
          alternative.increment_completion
        else
          self.goals.each {|g|
            if !experiment.finished?(split_id, g)
              alternative.increment_unique_completion(g, self.value)
              experiment.finish!(split_id, g)
            end
            alternative.increment_completion(g, self.value)
          }
        end
      end
    end

    def choose!
      choose
      if !experiment.participating?(split_id)
        record!
      end
    end

    def record!
      alternative.increment_participation
      experiment.participate!(split_id)
    end

    def choose
      self.alternative = experiment.next_alternative(split_id)
    end

    def alternative=(alternative)
      @alternative = if alternative.kind_of?(Split::Alternative)
        alternative
      else
        self.experiment.alternatives.find{|a| a.name == alternative }
      end
    end
  end
end
