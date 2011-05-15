module Multivariate
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

    def save
      if Multivariate.redis.hgetall("#{experiment_name}:#{name}")
        Multivariate.redis.hset "#{experiment_name}:#{name}", 'participant_count', @participant_count
        Multivariate.redis.hset "#{experiment_name}:#{name}", 'completed_count', @completed_count
      else
        Multivariate.redis.hmset "#{experiment_name}:#{name}", 'participant_count', 'completed_count', @participant_count, @completed_count
      end
    end

    def self.find(name, experiment_name)
      counters = Multivariate.redis.hgetall "#{experiment_name}:#{name}"
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