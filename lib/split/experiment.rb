module Split
  class Experiment
    attr_accessor :name
    attr_writer :algorithm
    attr_accessor :resettable
    attr_accessor :goals
    attr_accessor :alternatives
    attr_accessor :alternative_probabilities
    attr_accessor :metadata

    DEFAULT_OPTIONS = {
      :resettable => true
    }

    def initialize(name, options = {})
      options = DEFAULT_OPTIONS.merge(options)

      @name = name.to_s

      alternatives = extract_alternatives_from_options(options)

      if alternatives.empty? && (exp_config = Split.configuration.experiment_for(name))
        set_alternatives_and_options(
          alternatives: load_alternatives_from_configuration,
          goals: load_goals_from_configuration,
          metadata: load_metadata_from_configuration,
          resettable: exp_config[:resettable],
          algorithm: exp_config[:algorithm]
        )
      else
        set_alternatives_and_options(
          alternatives: alternatives,
          goals: options[:goals],
          metadata: options[:metadata],
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
      self.metadata = options[:metadata]
    end

    def extract_alternatives_from_options(options)
      alts = options[:alternatives] || []

      if alts.length == 1
        if alts[0].is_a? Hash
          alts = alts[0].map{|k,v| {k => v} }
        end
      end

      if alts.empty?
        exp_config = Split.configuration.experiment_for(name)
        if exp_config
          alts = load_alternatives_from_configuration
          options[:goals] = load_goals_from_configuration
          options[:metadata] = load_metadata_from_configuration
          options[:resettable] = exp_config[:resettable]
          options[:algorithm] = exp_config[:algorithm]
        end
      end

      self.alternatives = alts
      self.goals = options[:goals]
      self.algorithm = options[:algorithm]
      self.resettable = options[:resettable]

      # calculate probability that each alternative is the winner
      @alternative_probabilities = {}
      alts
    end

    def save
      validate!

      if new_record?
        Split.redis.sadd(:experiments, name)
        start unless Split.configuration.start_manually
        @alternatives.reverse.each {|a| Split.redis.lpush(name, a.name)}
        @goals.reverse.each {|a| Split.redis.lpush(goals_key, a)} unless @goals.nil?
        Split.redis.set(metadata_key, @metadata.to_json) unless @metadata.nil?
      else
        existing_alternatives = load_alternatives_from_redis
        existing_goals = load_goals_from_redis
        existing_metadata = load_metadata_from_redis
        unless existing_alternatives == @alternatives.map(&:name) && existing_goals == @goals && existing_metadata == @metadata
          reset
          @alternatives.each(&:delete)
          delete_goals
          delete_metadata
          Split.redis.del(@name)
          @alternatives.reverse.each {|a| Split.redis.lpush(name, a.name)}
          @goals.reverse.each {|a| Split.redis.lpush(goals_key, a)} unless @goals.nil?
          Split.redis.set(metadata_key, @metadata.to_json) unless @metadata.nil?
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

    def metadata_key
      "#{name}:metadata"
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
      delete_metadata
      Split.configuration.on_experiment_delete.call(self)
      increment_version
    end

    def delete_goals
      Split.redis.del(goals_key)
    end

    def delete_metadata
      Split.redis.del(metadata_key)
    end

    def load_from_redis
      exp_config = Split.redis.hgetall(experiment_config_key)
      self.resettable = exp_config['resettable']
      self.algorithm = exp_config['algorithm']
      self.alternatives = load_alternatives_from_redis
      self.goals = load_goals_from_redis
      self.metadata = load_metadata_from_redis
    end

    def calc_winning_alternatives
      if goals.empty?
        self.estimate_winning_alternative
      else
        goals.each do |goal|
          self.estimate_winning_alternative(goal)
        end
      end

      calc_time = Time.now.day

      self.save
    end

    def estimate_winning_alternative(goal = nil)
      # TODO - refactor out functionality to work with and without goals

      # initialize a hash of beta distributions based on the alternatives' conversion rates
      beta_params = calc_beta_params(goal)

      winning_alternatives = []

      Split.configuration.beta_probability_simulations.times do
        # calculate simulated conversion rates from the beta distributions
        simulated_cr_hash = calc_simulated_conversion_rates(beta_params)

        winning_alternative = find_simulated_winner(simulated_cr_hash)

        # push the winning pair to the winning_alternatives array
        winning_alternatives.push(winning_alternative)
      end

      winning_counts = count_simulated_wins(winning_alternatives)

      @alternative_probabilities = calc_alternative_probabilities(winning_counts, Split.configuration.beta_probability_simulations)

      write_to_alternatives(@alternative_probabilities, goal)

      self.save
    end

    def write_to_alternatives(alternative_probabilities, goal = nil)
      alternatives.each do |alternative|
        alternative.set_p_winner(@alternative_probabilities[alternative], goal)
      end
    end

    def calc_alternative_probabilities(winning_counts, number_of_simulations)
      alternative_probabilities = {}
      winning_counts.each do |alternative, wins|
        alternative_probabilities[alternative] = wins / number_of_simulations.to_f
      end
      return alternative_probabilities
    end

    def count_simulated_wins(winning_alternatives)
       # initialize a hash to keep track of winning alternative in simulations
      winning_counts = {}
      alternatives.each do |alternative|
        winning_counts[alternative] = 0
      end
      # count number of times each alternative won, calculate probabilities, place in hash
      winning_alternatives.each do |alternative|
        winning_counts[alternative] += 1
      end
      return winning_counts
    end

    def find_simulated_winner(simulated_cr_hash)
      # figure out which alternative had the highest simulated conversion rate
      winning_pair = ["",0.0]
      simulated_cr_hash.each do |alternative, rate|
        if rate > winning_pair[1]
          winning_pair = [alternative, rate]
        end
      end
      winner = winning_pair[0]
      return winner
    end

    def calc_simulated_conversion_rates(beta_params)
      # initialize a random variable (from which to simulate conversion rates ~beta-distributed)
      rand = SimpleRandom.new
      rand.set_seed

      simulated_cr_hash = {}

      # create a hash which has the conversion rate pulled from each alternative's beta distribution
      beta_params.each do |alternative, params|
        alpha = params[0]
        beta = params[1]
        simulated_conversion_rate = rand.beta(alpha, beta)
        simulated_cr_hash[alternative] = simulated_conversion_rate
      end

      return simulated_cr_hash
    end

    def calc_beta_params(goal = nil)
      beta_params = {}
      alternatives.each do |alternative|
        conversions = goal.nil? ? alternative.completed_count : alternative.completed_count(goal)
        alpha = 1 + conversions
        beta = 1 + alternative.participant_count - conversions

        params = [alpha, beta]

        beta_params[alternative] = params
      end
      return beta_params
    end

    def calc_time=(time)
      Split.redis.hset(experiment_config_key, :calc_time, time)
    end

    def calc_time
      Split.redis.hget(experiment_config_key, :calc_time)
    end

    def jstring(goal = nil)
      unless goal.nil?
        jstring = name + "-" + goal
      else
        jstring = name
      end
    end

    protected

    def experiment_config_key
      "experiment_configurations/#{@name}"
    end

    def load_metadata_from_configuration
      metadata = Split.configuration.experiment_for(@name)[:metadata]
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

    def load_metadata_from_redis
      meta = Split.redis.get(metadata_key)
      JSON.parse(meta) unless meta.nil?
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
