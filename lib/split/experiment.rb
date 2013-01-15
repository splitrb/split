module Split
  class Experiment
    attr_accessor :name
    attr_writer :algorithm
    attr_accessor :resettable
    attr_accessor :goals

    def initialize(name, options = {})
      options = {
          :resettable => true,
        }.merge(options)

      @name = name.to_s
      @alternatives = options[:alternatives]  if !options[:alternatives].nil?

      if !options[:goals].nil?
        @goals = options[:goals]
      end

      if !options[:algorithm].nil?
        @algorithm = options[:algorithm].is_a?(String) ? options[:algorithm].constantize : options[:algorithm]
      end

      if !options[:resettable].nil?
        @resettable = options[:resettable].is_a?(String) ? options[:resettable] == 'true' : options[:resettable]
      end

      if !options[:alternative_names].nil?
        @alternatives = options[:alternative_names].map do |alternative|
                          Split::Alternative.new(alternative, name)
                        end
      end


    end

    def algorithm
      @algorithm ||= Split.configuration.algorithm
    end

    def ==(obj)
      self.name == obj.name
    end

    def winner
      if w = Split.redis.hget(:experiment_winner, name)
        Split::Alternative.new(w, name)
      else
        nil
      end
    end

    def participant_count
      alternatives.inject(0){|sum,a| sum + a.participant_count}
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
      if alternatives.length > 1
        Split.configuration.algorithm.choose_alternative(self)
      else
        alternatives.first
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

    def self.goals_key(name)
      "#{name}:goals"
    end

    def goals_key
      self.class.goals_key(self.name)
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
      delete_goals
      increment_version
    end

    def delete_goals
      Split.redis.del(goals_key)
    end

    def new_record?
      !Split.redis.exists(name)
    end

    def save
      if new_record?
        Split.redis.sadd(:experiments, name)
        Split.redis.hset(:experiment_start_times, @name, Time.now)
        @alternatives.reverse.each {|a| Split.redis.lpush(name, a.name)}
        @goals.reverse.each {|a| Split.redis.lpush(goals_key, a)} unless @goals.nil?
      else
        Split.redis.del(name)
        @alternatives.reverse.each {|a| Split.redis.lpush(name, a.name)}
        @goals.reverse.each {|a| Split.redis.lpush(goals_key, a)} unless @goals.nil?
      end
      config_key = Split::Experiment.experiment_config_key(name)
      Split.redis.hset(config_key, :resettable, resettable)
      Split.redis.hset(config_key, :algorithm, algorithm.to_s)
      self
    end

    def self.load_goals_for(name)
      if Split.configuration.experiment_for(name)
        load_goals_from_configuration_for(name)
      else
        load_goals_from_redis_for(name)
      end
    end

    def self.load_goals_from_configuration_for(name)
      goals = Split.configuration.experiment_for(name)[:goals]
      if goals.nil?
        goals = []
      else
        goals.flatten
      end
    end

    def self.load_goals_from_redis_for(name)
      Split.redis.lrange(goals_key(name), 0, -1)
    end

    def self.load_alternatives_for(name)
      if Split.configuration.experiment_for(name)
        load_alternatives_from_configuration_for(name)
      else
        load_alternatives_from_redis_for(name)
      end
    end

    def self.load_alternatives_from_configuration_for(name)
      alts = Split.configuration.experiment_for(name)[:alternatives]
      raise ArgumentError, "Experiment configuration is missing :alternatives array" if alts.nil?
      if alts.is_a?(Hash)
        alts.keys
      else
        alts.flatten
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
      exp_config = Split.configuration.experiment_for(name) || {}
      self.new(name, :alternative_names => load_alternatives_for(name),
                     :goals => load_goals_for(name),
                     :resettable => exp_config[:resettable],
                     :algorithm => exp_config[:algorithm])
    end

    def self.load_from_redis(name)
      exp_config = Split.redis.hgetall(experiment_config_key(name))
      self.new(name, :alternative_names => load_alternatives_for(name),
                     :goals => load_goals_for(name),
                     :resettable => exp_config['resettable'],
                     :algorithm => exp_config['algorithm'])
    end

    def self.experiment_config_key(name)
      "experiment_configurations/#{name}"
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

    def self.find_or_create(label, *alternatives)
      experiment_name_with_version, goals = normalize_experiment(label)
      name = experiment_name_with_version.to_s.split(':')[0]

      if alternatives.length == 1
        if alternatives[0].is_a? Hash
          alternatives = alternatives[0].map{|k,v| {k => v} }
        end
      end

      alts = initialize_alternatives(alternatives, name)
      gls = initialize_goals(goals)

      if Split.redis.exists(name)
        existing_alternatives = load_alternatives_for(name)
        existing_goals = load_goals_for(name)
        if existing_alternatives == alts.map(&:name) && existing_goals == gls
          experiment = self.new(name, :alternative_names => alternatives, :goals => goals)
        else
          exp = self.new(name, :alternative_names => existing_alternatives, :goals => goals)
          exp.reset
          exp.alternatives.each(&:delete)
          exp.delete_goals
          experiment = self.new(name, :alternative_names =>alternatives, :goals => goals)
          experiment.save
        end
      else
        experiment = self.new(name, :alternative_names => alternatives, :goals => goals)
        experiment.save
      end
      return experiment

    end

    def self.normalize_experiment(label)
      if Hash === label
        experiment_name = label.keys.first
        goals = label.values.first
      else
        experiment_name = label
        goals = []
      end
      return experiment_name, goals
    end

    def self.initialize_alternatives(alternatives, name)

      unless alternatives.all? { |a| Split::Alternative.valid?(a) }
        raise ArgumentError, 'Alternatives must be strings'
      end

      alternatives.map do |alternative|
        Split::Alternative.new(alternative, name)
      end
    end

    def self.initialize_goals(goals)
      raise ArgumentError, 'Goals must be an array' unless valid_goals?(goals)
      goals
    end

    def self.valid_goals?(goals)
      Array === goals rescue false
    end
  end
end
