module Split
  class Experiment
    attr_accessor :name
    attr_writer :algorithm
    attr_accessor :resettable

    def initialize(name, *alternative_names)
      @name = name.to_s
      @resettable = true
      @alternatives = alternative_names.map do |alternative|
                        Split::Alternative.new(alternative, name)
                      end
    end
    
    def algorithm
      @algorithm ||= (load_algorithm || Split.configuration.algorithm)
    end

    def ==(obj)
      self.name == obj.name
    end
    
    def load_algorithm
      alg = Split.redis.hget(:experiment_algorithms, name) 
      if alg
        alg.constantize
      else
        nil
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
    
    def [](name)
      alternatives.find{|a| a.name == name} 
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
      Split.configuration.algorithm.choose_alternative(self)
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

    def resettable?
      resettable
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
        Split.redis.hset(:experiment_start_times, @name, Time.now)
        Split.redis.hset(:experiment_algorithms, @name, algorithm.to_s)
        @alternatives.reverse.each {|a| Split.redis.lpush(name, a.name) }
      else
        Split.redis.del(name)
        @alternatives.reverse.each {|a| Split.redis.lpush(name, a.name) }
      end
    end

    def self.load_alternatives_for(name)
      if Split.configuration.experiment_for(name)
        load_alternatives_from_configuration_for(name)
      else
        load_alternatives_from_redis_for(name)
      end
    end

    def self.load_alternatives_from_configuration_for(name)
      alts = Split.configuration.experiment_for(name)[:variants]
      if alts.is_a?(Hash)
        alts.keys
      else
        alts
      end
    end



    def self.load_alternatives_from_redis_for(name)
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

    def self.load_from_configuration(name)
      obj = self.new(name, *load_alternatives_for(name))
      exp_config = Split.configuration.experiment_for(name)
      if exp_config
        obj.resettable = exp_config[:resettable] unless exp_config[:resettable].nil?
      else
        obj.resettable = true
      end
      obj
    end

    def self.load_from_redis(name)
      self.new(name, *load_alternatives_for(name))
    end

    def self.all
      Array(all_experiment_names_from_redis + all_experiment_names_from_configuration).map {|e| find(e)}
    end

    def self.all_experiment_names_from_redis
      Split.redis.smembers(:experiments)
    end

    def self.all_experiment_names_from_configuration
      Split.configuration.experiments ? Split.configuration.experiments.keys : []
    end


    def self.find(name)
      if Split.configuration.experiment_for(name)
        obj = load_from_configuration(name)
      elsif Split.redis.exists(name)
        obj = load_from_redis(name)
      else
        obj = nil
      end
      obj
    end

    def self.find_or_create(key, *alternatives)
      name = key.to_s.split(':')[0]

      if alternatives.length == 1
        if alternatives[0].is_a? Hash
          alternatives = alternatives[0].map{|k,v| {k => v} }
        else
          raise ArgumentError, 'You must declare at least 2 alternatives'
        end
      end

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
