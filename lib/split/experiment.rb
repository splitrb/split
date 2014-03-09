module Split
  class Experiment
    attr_accessor :name
    attr_writer :algorithm
    attr_accessor :resettable
    attr_accessor :goals
    attr_accessor :alternatives

    DEFAULT_OPTIONS = {
      :resettable => true,
    }

    def initialize(name, options = {})
      options = DEFAULT_OPTIONS.merge(options)

      @name = name.to_s

      alternatives = extract_alternatives_from_options(options)

      if alternatives.empty? && (exp_config = Split.configuration.experiment_for(name))
        set_alternatives_and_options(
          alternatives: load_alternatives_from_configuration,
          goals: load_goals_from_configuration,
          resettable: exp_config[:resettable],
          algorithm: exp_config[:algorithm]
        )
      else
        set_alternatives_and_options(
          alternatives: alternatives,
          goals: options[:goals],
          resettable: options[:resettable],
          algorithm: options[:algorithm]
        )
      end
    end

    def set_alternatives_and_options(options)
      self.alternatives = options[:alternatives]
      self.goals = options[:goals]
      self.resettable = options[:resettable]
      self.algorithm = options[:algorithm]
    end

    def extract_alternatives_from_options(options)
      alts = options[:alternatives] || []

      if alts.length == 1
        if alts[0].is_a? Hash
          alts = alts[0].map{|k,v| {k => v} }
        end
      end

      alts
    end

    def self.all
      ExperimentCatalog.all
    end

    # Return experiments without a winner (considered "active") first
    def self.all_active_first
      ExperimentCatalog.all_active_first
    end

    def self.find(name)
      ExperimentCatalog.find(name)
    end

    def self.find_or_create(label, *alternatives)
      ExperimentCatalog.find_or_create(label, *alternatives)
    end

    def save
      validate!

      if new_record?
        Split.redis.sadd(:experiments, name)
        start unless Split.configuration.start_manually
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

    def validate!
      if @alternatives.empty? && Split.configuration.experiment_for(@name).nil?
        raise ExperimentNotFound.new("Experiment #{@name} not found")
      end
      @alternatives.each {|a| a.validate! }
      unless @goals.nil? || goals.kind_of?(Array)
        raise ArgumentError, 'Goals must be an array'
      end
    end

    def new_record?
      !Split.redis.exists(name)
    end

    def ==(obj)
      self.name == obj.name
    end

    def [](name)
      alternatives.find{|a| a.name == name}
    end

    def algorithm
      @algorithm ||= Split.configuration.algorithm
    end

    def algorithm=(algorithm)
      @algorithm = algorithm.is_a?(String) ? algorithm.constantize : algorithm
    end

    def resettable=(resettable)
      @resettable = resettable.is_a?(String) ? resettable == 'true' : resettable
    end

    def alternatives=(alts)
      @alternatives = alts.map do |alternative|
        if alternative.kind_of?(Split::Alternative)
          alternative
        else
          Split::Alternative.new(alternative, @name)
        end
      end
    end

    def winner
      if w = Split.redis.hget(:experiment_winner, name)
        Split::Alternative.new(w, name)
      else
        nil
      end
    end

    def has_winner?
      !winner.nil?
    end

    def winner=(winner_name)
      Split.redis.hset(:experiment_winner, name, winner_name.to_s)
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

    def start
      Split.redis.hset(:experiment_start_times, @name, Time.now.to_i)
    end

    def start_time
      t = Split.redis.hget(:experiment_start_times, @name)
      if t
        # Check if stored time is an integer
        if t =~ /^[-+]?[0-9]+$/
          t = Time.at(t.to_i)
        else
          t = Time.parse(t)
        end
      end
    end

    def next_alternative
      winner || random_alternative
    end

    def random_alternative
      if alternatives.length > 1
        algorithm.choose_alternative(self)
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
      Split.configuration.on_experiment_reset.call(self)
      increment_version
    end

    def delete
      alternatives.each(&:delete)
      reset_winner
      Split.redis.srem(:experiments, name)
      Split.redis.del(name)
      delete_goals
      Split.configuration.on_experiment_delete.call(self)
      increment_version
    end

    def delete_goals
      Split.redis.del(goals_key)
    end

    def load_from_redis
      exp_config = Split.redis.hgetall(experiment_config_key)
      self.resettable = exp_config['resettable']
      self.algorithm = exp_config['algorithm']
      self.alternatives = load_alternatives_from_redis
      self.goals = load_goals_from_redis
    end

    protected

    def experiment_config_key
      "experiment_configurations/#{@name}"
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
      raise ArgumentError, "Experiment configuration is missing :alternatives array" unless alts
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

  end
end
