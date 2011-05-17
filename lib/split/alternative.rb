module Split
  class Alternative
    attr_accessor :name
    attr_accessor :participant_count
    attr_accessor :completed_count
    attr_accessor :experiment_name

    def initialize(name, experiment_name, counters = {})
      @experiment_name = experiment_name
      @name = name
      @participant_count = counters['participant_count'].to_i
      @completed_count = counters['completed_count'].to_i
    end

    def increment_participation
      @participant_count +=1
      self.save
    end

    def increment_completion
      @completed_count +=1
      self.save
    end

    def conversion_rate
      return 0 if participant_count.zero?
      (completed_count.to_f/participant_count.to_f)
    end
    
    def z_score      
      # CTR_E = the CTR within the experiment split
      # CTR_C = the CTR within the control split
      # E = the number of impressions within the experiment split
      # C = the number of impressions within the control split
      
      experiment = Split::Experiment.find(@experiment_name)
      control = experiment.alternatives[0]
      alternative = self
      
      return 'N/A' if control.name == alternative.name
      
      ctr_e = alternative.conversion_rate
      ctr_c = control.conversion_rate

      e = alternative.participant_count
      c = control.participant_count

      standard_deviation = ((ctr_e / ctr_c**3) * ((e*ctr_e)+(c*ctr_c)-(ctr_c*ctr_e)*(c+e))/(c*e)) ** 0.5
      
      z_score = ((ctr_e / ctr_c) - 1) / standard_deviation
    end

    def save
      if Split.redis.hgetall("#{experiment_name}:#{name}")
        Split.redis.hset "#{experiment_name}:#{name}", 'participant_count', @participant_count
        Split.redis.hset "#{experiment_name}:#{name}", 'completed_count', @completed_count
      else
        Split.redis.hmset "#{experiment_name}:#{name}", 'participant_count', 'completed_count', @participant_count, @completed_count
      end
    end

    def self.find(name, experiment_name)
      counters = Split.redis.hgetall "#{experiment_name}:#{name}"
      self.new(name, experiment_name, counters)
    end

    def self.find_or_create(name, experiment_name)
      self.find(name, experiment_name) || self.create(name, experiment_name)
    end

    def self.create(name, experiment_name)
      alt = self.new(name, experiment_name)
      alt.save
      alt
    end
  end
end