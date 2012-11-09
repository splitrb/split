module Split
  class Experiment
    attr_accessor :name

    def initialize(name, *alternative_names)
      @name = name.to_s
      @alternatives = alternative_names.map do |alternative|
                        Split::Alternative.new(alternative, name)
                      end
    end

    def winner
      if w = Split.redis.hget(:experiment_winner, name)
        Split::Alternative.new(w, name)
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

    def start_time
      t = Split.redis.hget(:experiment_start_times, @name)
      Time.parse(t) if t
    end

    def alternatives
      @alternatives.dup
    end

    def alternative_names
      @alternatives.map(&:name)
    end

    def next_alternative
      winner || random_alternative
    end

    def random_alternative
      weights = alternatives.map(&:weight)

      total = weights.inject(:+)
      point = rand * total

      alternatives.zip(weights).each do |n,w|
        return n if w >= point
        point -= w
      end
    end

    def version
      @version ||= (Split.redis.get("#{name.to_s}:version").to_i || 0)
    end

    def increment_version
      @version = Split.redis.incr("#{name}:version")
    end

    def key
      if version.to_i > 0
        "#{name}:#{version}"
      else
        name
      end
    end

    def finished_key
      "#{key}:finished"
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
      new_record? ? persist : overwrite
    end

    def persist
      Split.redis.sadd(:experiments, name)
      Split.redis.hset(:experiment_start_times, @name, Time.now)
      @alternatives.reverse.each {|a| Split.redis.lpush(name, a.name) }
    end

    def overwrite
      Split.redis.del(name)
      @alternatives.reverse.each {|a| Split.redis.lpush(name, a.name) }
    end

    def self.load_alternatives_for(name)
      case Split.redis.type(name)
      when 'set' # convert legacy sets to lists
        convert_legacy_sets(name)
      else
        Split.redis.lrange(name, 0, -1)
      end
    end
    
    def self.convert_legacy_sets(name)
      alts = Split.redis.smembers(name)
      Split.redis.del(name)
      alts.reverse.each {|a| Split.redis.lpush(name, a) }
      Split.redis.lrange(name, 0, -1)
    end

    def self.all
      Array(Split.redis.smembers(:experiments)).map {|e| find(e)}
    end

    def self.find(name)
      if Split.redis.exists(name)
        self.new(name, *load_alternatives_for(name))
      end
    end
    
    def self.name_from_key(key)
      key.to_s.split(':')[0]
    end
    
    def self.process_alternatives(*alternatives)
      if alternatives.length == 1
        if alternatives[0].is_a? Hash
          alternatives = alternatives[0].map{|k,v| {k => v} }
          return alternatives
        else
          raise ArgumentError, 'You must declare at least 2 alternatives'
        end
      end
      alternatives
    end

    def self.find_or_create(key, *alternatives)
      name = name_from_key(key)
      alternatives = process_alternatives(*alternatives)
      alts = initialize_alternatives(alternatives, name)

      if Split.redis.exists(name)
        existing_alternatives = load_alternatives_for(name)
        if existing_alternatives == alts.map(&:name)
          experiment = self.new(name, *alternatives)
        else
          exp = self.new(name, *existing_alternatives)
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

    def self.initialize_alternatives(alternatives, name)

      unless alternatives.all? { |a| Split::Alternative.valid?(a) }
        raise ArgumentError, 'Alternatives must be strings'
      end

      alternatives.map do |alternative|
        Split::Alternative.new(alternative, name)
      end
    end
  end
end
