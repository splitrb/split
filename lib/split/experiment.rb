module Split
  class Experiment
    attr_accessor :name
    attr_accessor :alternative_names
    attr_accessor :winner
    attr_accessor :version

    def initialize(name, *alternative_names)
      @name = name.to_s
      @alternative_names = alternative_names
      @version = (Split.redis.get("#{name.to_s}:version").to_i || 0)
    end

    def winner
      if w = Split.redis.hget(:experiment_winner, name)
        return Split::Alternative.find(w, name)
      else
        nil
      end
    end

    def control
      alternatives.first
    end

    def reset_winner
      Split.redis.hdel(:experiment_winner, name)
    end

    def winner=(winner_name)
      Split.redis.hset(:experiment_winner, name, winner_name.to_s)
    end

    def alternatives
      @alternative_names.map {|a| Split::Alternative.find_or_create(a, name)}
    end

    def next_alternative
      winner || alternatives.sort_by{|a| a.participant_count + rand}.first
    end

    def version
      @version ||= 0
    end

    def increment_version
      @version += 1
      Split.redis.set("#{name}:version", @version)
    end

    def key
      if version.to_i > 0
        "#{name}:#{version}"
      else
        name
      end
    end

    def reset
      alternatives.each(&:reset)
      reset_winner
      increment_version
    end

    def delete
      alternatives.each(&:delete)
      reset_winner
      Split.redis.srem(:experiments, name)
      Split.redis.del(name)
      increment_version
    end

    def new_record?
      !Split.redis.exists(name)
    end

    def save
      if new_record?
        Split.redis.sadd(:experiments, name)
        @alternative_names.reverse.each {|a| Split.redis.lpush(name, a) }
      end
    end

    def self.load_alternatives_for(name)
      case Split.redis.type(name)
      when 'set' # convert legacy sets to lists
        alts = Split.redis.smembers(name)
        Split.redis.del(name)
        alts.reverse.each {|a| Split.redis.lpush(name, a) }
        Split.redis.lrange(name, 0, -1)
      else
        Split.redis.lrange(name, 0, -1)
      end
    end

    def self.all
      Array(Split.redis.smembers(:experiments)).map {|e| find(e)}
    end

    def self.find(name)
      if Split.redis.exists(name)
        self.new(name, *load_alternatives_for(name))
      else
        raise 'Experiment not found'
      end
    end

    def self.find_or_create(key, *alternatives)
      name = key.to_s.split(':')[0]

      raise InvalidArgument, 'Alternatives must be strings' if alternatives.map(&:class).uniq != [String]

      if Split.redis.exists(name)
        if load_alternatives_for(name) == alternatives
          experiment = self.new(name, *load_alternatives_for(name))
        else
          exp = self.new(name, *load_alternatives_for(name))
          exp.reset
          exp.alternatives.each(&:delete)
          experiment = self.new(name, *alternatives)
          experiment.save
        end
      else
        experiment = self.new(name, *alternatives)
        experiment.save
      end
      return experiment
    end
  end
end