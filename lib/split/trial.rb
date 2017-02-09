module Split
  class Trial
    attr_accessor :experiment
    attr_accessor :goals
    attr_accessor :value
    attr_accessor :users
    
    def initialize(attrs = {})
      self.experiment = attrs[:experiment]  if !attrs[:experiment].nil?
      self.goals = attrs[:goals].nil? ? [] : attrs[:goals]
      self.value = attrs[:value] if !attrs[:value].nil?
      self.users = Array(attrs[:users]) if !attrs[:users].nil?
    end

    def alternative
      @alternative ||=
      begin
        if @users.length <= 1
          choose
          @alternatives.values.first
        else
          false
        end
      end
    end

    def complete!
      if alternative
        if self.goals.empty?
          users.each do |user|
            if !experiment.finished?(user)
              alternative.increment_unique_completion
              experiment.finish!(user)
            end
            alternative.increment_completion
          end
        else
          self.goals.each {|g|
            users.each do |user|
              if !experiment.finished?(user, g)
                alternative.increment_unique_completion(g, self.value)
                experiment.finish!(user, g)
              end
              alternative.increment_completion(g, self.value)
            end
          }
        end
        return true
      else
        return false
      end
    end

    def choose!
      choose
      record!

      @alternatives.update(@alternatives){|user, alternative| alternative.name}
      @alternatives
    end

    def record!
      @alternatives.group_by{|user,alternative| alternative}.each_pair do |alternative, pairs|
        non_participating_users = pairs.select{|pair| !experiment.participating?(pair[0]) }.collect{|n| n[0]}
        alternative.increment_participation(non_participating_users.length)
        experiment.participate!(non_participating_users)
      end
    end

    private
    def choose
      @alternatives ||= {}
      users.each do |user|
        @alternatives[user] = experiment.random_alternative(user)
      end
    end
  end
end
