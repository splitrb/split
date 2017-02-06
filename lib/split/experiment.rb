# frozen_string_literal: true
module Split
  class Experiment
    attr_accessor :name
    attr_writer :algorithm
    attr_accessor :resettable
    attr_accessor :goals
    attr_accessor :alternatives
    attr_accessor :alternative_probabilities
    attr_accessor :metadata
    attr_accessor :scores

    DEFAULT_OPTIONS = {
      resettable: true,
      scores: []
    }.freeze

    def initialize(name, options = {})
      options = DEFAULT_OPTIONS.merge(options)

      @name = name.to_s

      alternatives = extract_alternatives_from_options(options)

      if alternatives.empty? && (exp_config = Split.configuration.experiment_for(name))
        options = {
          alternatives: load_alternatives_from_configuration,
          goals: Split::GoalsCollection.new(@name).load_from_configuration,
          metadata: load_metadata_from_configuration,
          resettable: exp_config[:resettable],
          algorithm: exp_config[:algorithm],
          scores: Split::ScoresCollection.new(@name).load_from_configuration
        }
      else
        options[:alternatives] = alternatives
      end

      set_alternatives_and_options(options)
    end

    def self.finished_key(key)
      "#{key}:finished"
    end

    def self.scored_key(key, score_name)
      "#{key}:scored:#{score_name}"
    end

    def set_alternatives_and_options(options)
      self.alternatives = options[:alternatives]
      self.goals = options[:goals]
      self.resettable = options[:resettable]
      self.algorithm = options[:algorithm]
      self.metadata = options[:metadata]
      self.scores = options[:scores]
    end

    def extract_alternatives_from_options(options)
      alts = options[:alternatives] || []

      if alts.length == 1
        alts = alts[0].map { |k, v| { k => v } } if alts[0].is_a? Hash
      end

      if alts.empty?
        exp_config = Split.configuration.experiment_for(name)
        if exp_config
          alts = load_alternatives_from_configuration
          options[:goals] = Split::GoalsCollection.new(@name).load_from_configuration
          options[:metadata] = load_metadata_from_configuration
          options[:resettable] = exp_config[:resettable]
          options[:algorithm] = exp_config[:algorithm]
          options[:scores] = Split::ScoresCollection.new(@name).load_from_configuration
        end
      end

      options[:alternatives] = alts

      set_alternatives_and_options(options)

      # calculate probability that each alternative is the winner
      @alternative_probabilities = {}
      alts
    end

    def save
      validate!
      if new_record?
        start unless Split.configuration.start_manually
        redis.sadd(:experiments, name)
        redis_data[:is_new_record] = false
      end
      self
    end

    def validate!
      if @alternatives.empty? && Split.configuration.experiment_for(@name).nil?
        raise ExperimentNotFound, "Experiment #{@name} not found"
      end
      @alternatives.each(&:validate!)
      goals_collection.validate!
      scores_collection.validate!
    end

    def new_record?
      redis_data[:is_new_record]
    end

    def ==(other)
      name == other&.name
    end

    def [](name)
      alternatives.find { |a| a.name == name }
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
        if alternative.is_a?(Split::Alternative)
          alternative
        else
          Split::Alternative.new(alternative, @name)
        end
      end
    end

    def winner
      return nil unless redis_data[:winner_name]
      Split::Alternative.new(redis_data[:winner_name], name)
    end

    def has_winner?
      !winner.nil?
    end

    def winner=(winner_name)
      redis.hset(:experiment_winner, name, winner_name.to_s)
      redis_data[:winner_name] = winner_name.to_s
      winner
    end

    def participant_count
      alternatives.inject(0) { |sum, a| sum + a.participant_count }
    end

    def control
      alternatives.first
    end

    def reset_winner
      redis.hdel(:experiment_winner, name)
      redis_data[:winner_name] = nil
    end

    def start
      time = Time.now.to_i
      redis.hset(:experiment_start_times, @name, time)
      redis_data[:start_time] = time.to_s
    end

    def start_time
      t = redis_data[:start_time]
      return unless t
      # Check if stored time is an integer
      if t =~ /^[-+]?[0-9]+$/
        Time.at(t.to_i)
      else
        Time.parse(t)
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
      redis_data[:version].to_i
    end

    def increment_version
      redis_data[:version] = redis.incr("#{name}:version")
    end

    def key
      if version.positive?
        "#{name}:#{version}"
      else
        name
      end
    end

    def finished_key
      self.class.finished_key(key)
    end

    def scored_key(score_name)
      self.class.scored_key(key, score_name)
    end

    def resettable?
      resettable
    end

    def reset
      Split.configuration.on_before_experiment_reset.call(self)
      alternatives.each(&:reset)
      reset_winner
      Split.configuration.on_experiment_reset.call(self)
      increment_version
    end

    def delete
      Split.configuration.on_before_experiment_delete.call(self)
      if Split.configuration.start_manually
        redis.hdel(:experiment_start_times, @name)
        redis_data[:start_time] = nil
      end
      reset_winner
      redis.srem(:experiments, name)
      redis_data[:is_new_record] = true
      alternatives.each(&:delete)
      Split.configuration.on_experiment_delete.call(self)
      increment_version
    end

    def load_from_redis
      redis_data
      self
    end

    def calc_winning_alternatives
      if goals.empty?
        estimate_winning_alternative
      else
        goals.each do |goal|
          estimate_winning_alternative(goal)
        end
      end
      self
    end

    def estimate_winning_alternative(goal = nil)
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

      write_to_alternatives(goal)

      self
    end

    def write_to_alternatives(goal = nil)
      alternatives.each do |alternative|
        alternative.set_p_winner(@alternative_probabilities[alternative], goal)
      end
    end

    def calc_alternative_probabilities(winning_counts, number_of_simulations)
      alternative_probabilities = {}
      winning_counts.each do |alternative, wins|
        alternative_probabilities[alternative] = wins / number_of_simulations.to_f
      end
      alternative_probabilities
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
      winning_counts
    end

    def find_simulated_winner(simulated_cr_hash)
      # figure out which alternative had the highest simulated conversion rate
      winning_pair = ['', 0.0]
      simulated_cr_hash.each do |alternative, rate|
        winning_pair = [alternative, rate] if rate > winning_pair[1]
      end
      winner = winning_pair[0]
      winner
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

      simulated_cr_hash
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
      beta_params
    end

    def jstring(goal = nil)
      js_id = if goal.nil?
                name
              else
                name + '-' + goal
              end
      js_id.gsub('/', '--')
    end

    protected

    def load_metadata_from_configuration
      Split.configuration.experiment_for(@name)[:metadata]
    end

    def load_alternatives_from_configuration
      alts = Split.configuration.experiment_for(@name)[:alternatives]
      raise ArgumentError, 'Experiment configuration is missing :alternatives array' unless alts
      if alts.is_a?(Hash)
        alts.keys
      else
        alts.flatten
      end
    end

    private

    def redis
      Split.redis
    end

    def redis_data
      return @redis_data if defined?(@redis_data)
      @redis_data = {}
      tmp_version, tmp_winner_name, tmp_start_time, tmp_new_record = redis.pipelined do
        redis.get("#{name}:version")
        redis.hget(:experiment_winner, name)
        redis.hget(:experiment_start_times, @name)
        redis.sismember(:experiments, @name)
      end
      @redis_data[:version] = tmp_version
      @redis_data[:winner_name] = tmp_winner_name
      @redis_data[:start_time] = tmp_start_time
      @redis_data[:is_new_record] = !tmp_new_record
      @redis_data
    end

    def redis_interface
      RedisInterface.new
    end

    def delete_alternatives
      @alternatives.each(&:delete)
    end

    def goals_collection
      Split::GoalsCollection.new(@name, @goals)
    end

    def scores_collection
      Split::ScoresCollection.new(@name, @scores)
    end
  end
end
