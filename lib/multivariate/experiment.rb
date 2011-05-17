module Multivariate
  class Experiment
    attr_accessor :name
    attr_accessor :alternatives
    attr_accessor :winner

    def initialize(name, *alternatives)
      @name = name.to_s
      @alternatives = alternatives
      @winner = winner
    end

    def winner
      if w = Multivariate.redis.hget(:experiment_winner, name)
        Multivariate::Alternative.find(w, name)
      end
    end

    def alternatives
      @alternatives.map {|a| Multivariate::Alternative.find_or_create(a, name)}
    end

    def next_alternative
      @winner || alternatives.sort_by{|a| a.participant_count + rand}.first
    end

    def save
      Multivariate.redis.sadd(:experiments, name)
      @alternatives.each {|a| Multivariate.redis.sadd(name, a) }
      if @winner
        Multivariate.redis.hset(:experiment_winner, name, @winner.name)
      end
    end

    def self.all
      Array(Multivariate.redis.smembers(:experiments)).map {|e| find(e)}
    end

    def self.find(name)
      if Multivariate.redis.exists(name)
        self.new(name, *Multivariate.redis.smembers(name))
      else
        raise 'Experiment not found'
      end
    end

    def self.find_or_create(name, *alternatives)
      if Multivariate.redis.exists(name)
        return self.new(name, *Multivariate.redis.smembers(name))
      else
        experiment = self.new(name, *alternatives)
        experiment.save
        return experiment
      end
    end
  end
end