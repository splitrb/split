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

      @alternatives = options[:alternatives] || []

      if @alternatives.length == 1
        if @alternatives[0].is_a? Hash
          @alternatives = @alternatives[0].map{|k,v| {k => v} }
        end
      end

      if @alternatives.length.zero?
        exp_config = Split.configuration.experiment_for(name)
        if exp_config
          @alternatives = load_alternatives_from_configuration
          options[:goals] = load_goals_from_configuration
          options[:resettable] = exp_config[:resettable]
          options[:algorithm] = exp_config[:algorithm]
        end
      end

      @alternatives = @alternatives.map do |alternative|
        Split::Alternative.new(alternative, name)
      end

      if !options[:goals].nil?
        @goals = options[:goals]
      end

      if !options[:algorithm].nil?
        @algorithm = options[:algorithm].is_a?(String) ? options[:algorithm].constantize : options[:algorithm]
      end

      if !options[:resettable].nil?
        @resettable = options[:resettable].is_a?(String) ? options[:resettable] == 'true' : options[:resettable]
      end
    end

    def validate!
      if @alternatives.length.zero? && Split.configuration.experiment_for(@name).nil?
        raise ExperimentNotFound.new("Experiment #{@name} not found")
      end
      @alternatives.each {|a| a.validate! }
      unless @goals.nil? || goals.kind_of?(Array)
        raise ArgumentError, 'Goals must be an array'
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

    def goals_key
      "#{name}:goals"
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
      validate!

      if new_record?
        Split.redis.sadd(:experiments, name)
        Split.redis.hset(:experiment_start_times, @name, Time.now)
        @alternatives.reverse.each {|a| Split.redis.lpush(name, a.name)}
        @goals.reverse.each {|a| Split.redis.lpush(goals_key, a)} unless @goals.nil?
      else

        existing_alternatives = load_alternatives_from_redis
        existing_goals = load_goals_from_redis
        unless existing_alternatives == @alternatives.map(&:name) && existing_goals == @goals
          reset
          @alternatives.each(&:delete)
          delete_goals
          Split.redis.del(@name)
          @alternatives.reverse.each {|a| Split.redis.lpush(name, a.name)}
          @goals.reverse.each {|a| Split.redis.lpush(goals_key, a)} unless @goals.nil?
        end
      end
      Split.redis.hset(experiment_config_key, :resettable, resettable)
      Split.redis.hset(experiment_config_key, :algorithm, algorithm.to_s)
      self
    end

    def load_goals_from_configuration
      goals = Split.configuration.experiment_for(@name)[:goals]
      if goals.nil?
        goals = []
      else
        goals.flatten
      end
    end

    def load_goals_from_redis
      Split.redis.lrange(goals_key, 0, -1)
    end

    def load_alternatives_from_configuration
      alts = Split.configuration.experiment_for(@name)[:alternatives]
      raise ArgumentError, "Experiment configuration is missing :alternatives array" if alts.nil?
      if alts.is_a?(Hash)
        alts.keys
      else
        alts.flatten
      end
    end

    def load_alternatives_from_redis
      case Split.redis.type(@name)
      when 'set' # convert legacy sets to lists
        alts = Split.redis.smembers(@name)
        Split.redis.del(@name)
        alts.reverse.each {|a| Split.redis.lpush(@name, a) }
        Split.redis.lrange(@name, 0, -1)
      else
        Split.redis.lrange(@name, 0, -1)
      end
    end

    def load_from_redis
      exp_config = Split.redis.hgetall(experiment_config_key)
      @resettable = exp_config['resettable']
      @algorithm = exp_config['algorithm']
      @alternatives = load_alternatives_from_redis
      @goals = load_goals_from_redis
      #TODO duplication
      @alternatives = @alternatives.map do |alternative|
        Split::Alternative.new(alternative, name)
      end
      @algorithm = @algorithm.is_a?(String) ? @algorithm.constantize : @algorithmm
      @resettable = @resettable.is_a?(String) ? @resettable == 'true' : @resettable
    end

    def experiment_config_key
      "experiment_configurations/#{@name}"
    end

    def self.all
      #TODO
      Array(all_experiment_names_from_redis + all_experiment_names_from_configuration).map {|e| find(e)}
    end

    def self.all_experiment_names_from_redis
      Split.redis.smembers(:experiments)
    end

    def self.all_experiment_names_from_configuration
      Split.configuration.experiments ? Split.configuration.experiments.keys : []
    end

    def self.find(name)
      if Split.redis.exists(name)
        obj = self.new name
        obj.load_from_redis
      else
        obj = nil
      end
      obj
    end

    def self.find_or_create(label, *alternatives)
      experiment_name_with_version, goals = normalize_experiment(label)
      name = experiment_name_with_version.to_s.split(':')[0]

      exp = self.new name, :alternatives => alternatives, :goals => goals
      exp.save
      exp
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
  end
end
