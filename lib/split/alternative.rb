require 'split/zscore'

# TODO - take out require and implement using file paths?

module Split
  class Alternative
    attr_accessor :name
    attr_accessor :experiment_name
    attr_accessor :weight

    include Zscore

    def initialize(name, experiment_name)
      @experiment_name = experiment_name
      if Hash === name
        @name = name.keys.first
        @weight = name.values.first
      else
        @name = name
        @weight = 1
      end
    end

    def to_s
      name
    end

    def goals
      self.experiment.goals
    end

    def participant_count
      Split.redis.with do |conn|
        conn.hget(key, 'participant_count').to_i
      end
    end

    def participant_count=(count)
      Split.redis.with do |conn|
        conn.hset(key, 'participant_count', count.to_i)
      end
    end

    def completed_count(goal = nil)
      field = set_field(goal)
      Split.redis.with do |conn|
        conn.hget(key, field).to_i
      end
    end

    def completed_value(goal = nil)
      field = set_value_field(goal)
      Split.redis.with do |conn|
        list = conn.lrange(key + field, 0, -1)
        puts list.inspect
        if list.size > 0
          list.sum{|n| n.to_f}/list.size
        else
          "N/A"
        end
      end
    end

    def combined_value(goal = nil)
      if completed_value(goal) != "N/A" && completed_count(goal) > 0
        completed_value(goal).to_f * (completed_count(goal).to_f/participant_count.to_f)
      else
        "N/A"
      end
    end

    def completed_values(goal = nil)
      field = set_value_field(goal)
      Split.redis.with do |conn|
        list = conn.lrange(key + field, 0, -1).collect{|n| n.to_f}
      end
    end

    def all_completed_count
      if goals.empty?
        completed_count
      else
        goals.inject(completed_count) do |sum, g|
          sum + completed_count(g)
        end
      end
    end

    def unfinished_count(goal = nil)
      participant_count - completed_count(goal)
    end

    def set_field(goal)
      field = "completed_count"
      field += ":" + goal unless goal.nil?
      return field
    end

    def set_value_field(goal)
      field = ":completed_value"
      field += ":" + goal unless goal.nil?
      return field
    end

    def set_completed_count (count, goal = nil)
      field = set_field(goal)
      Split.redis.with do |conn|
        conn.hset(key, field, count.to_i)
      end
    end

    def increment_participation
      Split.redis.with do |conn|
        conn.hincrby key, 'participant_count', 1
      end
    end

    def increment_completion(goal = nil, value = nil)
      Split.redis.with do |conn|
        field = set_field(goal)
        if value
          puts "SAVING VALUE"
          puts value
          conn.lpush(key + set_value_field(goal), value)
        end
        conn.hincrby(key, field, 1)
      end
    end

    def control?
      experiment.control.name == self.name
    end

    def conversion_rate(goal = nil)
      return 0 if participant_count.zero?
      (completed_count(goal).to_f)/participant_count.to_f
    end

    def experiment
      Split::Experiment.find(experiment_name)
    end

    def z_score(goal = nil)
      # p_a = Pa = proportion of users who converted within the experiment split (conversion rate)
      # p_c = Pc = proportion of users who converted within the control split (conversion rate)
      # n_a = Na = the number of impressions within the experiment split
      # n_c = Nc = the number of impressions within the control split

      control = experiment.control
      alternative = self

      return 'N/A' if control.name == alternative.name

      p_a = alternative.conversion_rate(goal)
      p_c = control.conversion_rate(goal)

      n_a = alternative.participant_count
      n_c = control.participant_count

      z_score = Split::Zscore.calculate(p_a, n_a, p_c, n_c)
    end

    def log_normal_probability_better_than_control(goal = nil)
      return "N/A" if experiment.control.name == self.name
      return "Needs 50+ participants." if self.completed_values(goal).size < 50

      if !self.completed_values(goal).blank? && !experiment.control.completed_values(goal).blank?
        bayesian_log_normal_probability(self.completed_values(goal).collect{|n| [0,n].max}, experiment.control.completed_values(goal).collect{|n| [0,n].max})
      else
        "N/A"
      end
    end

    def beta_samples(alternative, control)
      if alternative.is_a?(Array)
        non_zeros_a = alternative.size
        non_zeros_b = control.size
      else
        non_zeros_a = alternative
        non_zeros_b = control
      end

      puts("non_zeros_a")
      puts("-----------------------------------------------")
      puts(non_zeros_a.inspect)
      puts("-----------------------------------------------")
      puts("non_zeros_b")
      puts("-----------------------------------------------")
      puts(non_zeros_b.inspect)
      puts("-----------------------------------------------")

      total_a = self.participant_count
      total_b = experiment.control.participant_count

      puts("total_a")
      puts("-----------------------------------------------")
      puts(total_a.inspect)
      puts("-----------------------------------------------")
      puts("total_b")
      puts("-----------------------------------------------")
      puts(total_b.inspect)
      puts("-----------------------------------------------")

      alpha = 1
      beta = 1

      a_samples = []
      random_generator = SimpleRandom.new
      random_generator.set_seed(Time.now)
      10000.times do
        a_samples << random_generator.beta(non_zeros_a+alpha, [total_a-non_zeros_a, 0].max+beta)
      end

      b_samples = []
      random_generator.set_seed(Time.now)
      10000.times do
        b_samples << random_generator.beta(non_zeros_b+alpha, [total_b-non_zeros_b, 0].max+beta)
      end

      return a_samples, b_samples
    end

    def beta_probability_better_than_control(goal = nil)
      return "N/A" if experiment.control.name == self.name
      return "Needs 50+ participants." if self.participant_count < 50

      if self.completed_count(goal) > 0 && experiment.control.completed_count(goal) > 0
        bayesian_beta_probability(self.completed_count(goal), experiment.control.completed_count(goal))
      else
        "N/A"
      end
    end

    def combined_probability_better_than_control(goal = nil)
      return "N/A" if experiment.control.name == self.name
      return "Needs 50+ participants." if self.completed_values(goal).size < 50

      if self.combined_value(goal) != "N/A" && experiment.control.combined_value(goal) > 0
        bayesian_combined_probability(self.completed_values(goal).collect{|n| [0,n].max}, experiment.control.completed_values(goal).collect{|n| [0,n].max})
      else
        "N/A"
      end
    end

    def bayesian_combined_probability(alternative, control)
      puts("BAYESIAN COMBINED PROBABILITY")
      puts("-----------------------------------------------")
      a_rps_samps, b_rps_samps = bayesian_combined_samples(alternative, control)

      sum = 0
      a_rps_samps.each_with_index do |num, index|
        if num > b_rps_samps[index]
          sum += 1
        end
      end
      prob_A_greater_B = sum.to_f/a_rps_samps.size.to_f
    end

    def bayesian_combined_samples(alternative, control)
      puts("BAYESIAN COMBINED SAMPLES")
      puts("-----------------------------------------------")
      a_conv_samps, b_conv_samps = beta_samples(alternative, control)
      a_order_samps, b_order_samps = log_normal_samples(alternative, control)

      a_rps_samps = [a_conv_samps, a_order_samps].transpose.map {|x| x.reduce(:*)}
      b_rps_samps = [b_conv_samps, b_order_samps].transpose.map {|x| x.reduce(:*)}

      return a_rps_samps, b_rps_samps
    end

    def bayesian_beta_probability(alternative, control)
      puts("BAYESIAN BETA PROBABILITY")
      puts("-----------------------------------------------")
      a_samples, b_samples = beta_samples(alternative, control)

      sum = 0
      a_samples.each_with_index do |num, index|
        if num > b_samples[index]
          sum += 1
        end
      end
      prob_A_greater_B = sum.to_f/a_samples.size.to_f
    end

    def log_normal_samples(alternative, control)
      a_data = alternative
      b_data = control
      # a_data = [45,78,35,8,23,56,8,6,2,34,77,2,667,234,23,7,434,76,25,21,79,34,752]
      # b_data = [45,78,35,8,23,56,8,6,2,34,77,2,667,234,23,7,434,76,25,21,79,34,753]

      m0 = 4.0 # guess about the log of the mean
      k0 = 1.0 # certainty about m.  compare with number of data samples
      s_sq0 = 1.0 # degrees of freedom of sigma squared parameter
      v0 = 1.0 # scale of sigma_squared parameter

      # step 3: get posterior samples
      a_posterior_samples = draw_log_normal_means(a_data,m0,k0,s_sq0,v0)
      puts("a_posterior_samples")
      puts("--------------------------------")
      # puts(a_posterior_samples.inspect)
      # a_posterior_samples = [ 132.21672467, 104.79249553,  97.47489145, 201.3726052,  129.03142744, 233.90944597, 524.59244505, 142.80788793, 159.97628083, 167.96562996]
      b_posterior_samples = draw_log_normal_means(b_data,m0,k0,s_sq0,v0)
      puts("b_posterior_samples")
      puts("--------------------------------")
      # puts(b_posterior_samples.inspect)
      # b_posterior_samples = [  73.64035435, 100.94395081, 125.39778487,  75.84193507,  61.06892854, 153.61498405, 119.50436212,  77.33575107, 103.04974504, 219.81910446]

      return a_posterior_samples, b_posterior_samples
    end

    def bayesian_log_normal_probability(alternative, control)
      a_posterior_samples, b_posterior_samples = log_normal_samples(alternative, control)
      
      # step 4: perform numerical integration
      sum = 0
      a_posterior_samples.each_with_index do |num, index|
        if num > b_posterior_samples[index]
          sum += 1
        end
      end
      prob_A_greater_B = sum.to_f/a_posterior_samples.size.to_f
      # prob_A_greater_B = mean(a_posterior_samples > b_posterior_samples)
      puts prob_A_greater_B

      # or you can do more complicated lift calculations
      diff = [a_posterior_samples, b_posterior_samples].transpose.map {|x| x.reduce(:-)}
      temp_array = [diff, b_posterior_samples].transpose.map {|x| x.reduce(:/)}.collect{|n| n.to_f*100}
      # diff = a_posterior_samples - b_posterior_samples
      sum = 0
      temp_array.each_with_index do |num, index|
        if num > 1
          sum += 1
        end
      end
      lift_calc = sum.to_f/b_posterior_samples.size.to_f
      print lift_calc

      return prob_A_greater_B
    end

    def draw_log_normal_means(data,m0,k0,s_sq0,v0,n_samples=10000)
      # log transform the data
      log_data = data.collect{|n| Math.log(n)}

      # get samples from the posterior
      mu_samples, sig_sq_samples = draw_mus_and_sigmas(log_data,m0,k0,s_sq0,v0,n_samples)
      # transform into log-normal means
      puts("sig_sq_samples/2")
      puts "--------------------------------"
      # puts sig_sq_samples.collect{|n|n/2}.inspect
      puts "--------------------------------"
      log_normal_mean_samples = [sig_sq_samples.collect{|n|n/2}, mu_samples].transpose.map {|x| x.reduce(:+)}.collect{|n| Math.exp(n)}
      # log_normal_mean_samples = ( + ).collect{|n| Math.exp(n)}
      puts "--------------------------------"
      # puts log_normal_mean_samples.inspect
      return log_normal_mean_samples
    end

    def draw_mus_and_sigmas(data,m0,k0,s_sq0,v0,n_samples)
      # number of samples
      n = data.size
      puts n
      # find the mean of the data
      the_mean = data.sum{|n| n.to_f}/data.size
      puts "sum: #{data.sum{|n| n.to_f}}"
      puts "size: #{data.size}"
      puts the_mean
      # sum of squared differences between data and mean
      ssd = data.sum{|n| (n-the_mean)**2}
      puts ssd

      # combining the prior with the data - page 79 of Gelman et al.
      # to make sense of this note that
      # inv-chi-sq(v,s^2) = inv-gamma(v/2,(v*s^2)/2)
      kN = k0.to_f + n.to_f
      mN = (k0.to_f/kN.to_f)*m0.to_f + (n.to_f/kN.to_f)*the_mean.to_f
      vN = v0.to_f + n.to_f
      vN_times_s_sqN = v0.to_f*s_sq0.to_f + ssd.to_f + (n.to_f*k0.to_f*(m0.to_f-the_mean.to_f)**2)/kN.to_f

      # 1) draw the variances from an inverse gamma
      # (params: alpha, beta)
      alpha = vN/2
      beta = vN_times_s_sqN/2
      # thanks to wikipedia, we know that:
      # if X ~ inv-gamma(a,1) then b*X ~ inv-gamma(a,b)
      random_generator = SimpleRandom.new
      random_generator.set_seed(Time.now)
      sig_sq_samples = []
      (size=n_samples).times do
        sig_sq_samples << random_generator.inverse_gamma(alpha, beta)
      end
      # sig_sq_samples = [ 3.93387767, 2.86873865, 1.37857381, 1.44969198, 1.73889165, 4.40767376, 2.8204655,  5.40070993, 2.61998073, 2.43945704]

      puts("sig_sq_samples")
      puts("--------------------------------")
      # puts(sig_sq_samples.inspect)

      # 2) draw means from a normal conditioned on the drawn sigmas
      # (params: mean_norm, var_norm)
      mean_norm = mN
      puts("mean_norm")
      puts("--------------------------------")
      puts(mean_norm)
      var_norm = sig_sq_samples.collect{|n| Math.sqrt(n/kN)}
      puts("var_norm")
      puts("--------------------------------")
      # puts(var_norm.inspect)
      mu_samples = []
      var_norm.each do |var|
        mu_samples << random_generator.normal(mean_norm, var)
      end
      # mu_samples = [ 3.83535981, 4.32951363, 3.4837355,  4.04552639, 3.34382522, 3.44135176, 4.04160632, 3.05436931, 3.72039264, 3.31144501]

      puts("mu_samples")
      puts("--------------------------------")
      # puts(mu_samples.inspect)

      # 3) return the mu_samples and sig_sq_samples
      return mu_samples, sig_sq_samples
    end

    def save
      Split.redis.with do |conn|
        conn.hsetnx key, 'participant_count', 0
        conn.hsetnx key, 'completed_count', 0
      end
    end

    def validate!
      unless String === @name || hash_with_correct_values?(@name)
        raise ArgumentError, 'Alternative must be a string'
      end
    end

    def reset
      Split.redis.with do |conn|
        conn.hmset key, 'participant_count', 0, 'completed_count', 0
        unless goals.empty?
          goals.each do |g|
            field = "completed_count:#{g}"
            value_field = set_value_field(g)
            conn.hset key, field, 0
            conn.del(key + value_field)
          end
        end
      end
    end

    def delete
      Split.redis.with do |conn|
        conn.del(key)
      end
    end

    private

    def hash_with_correct_values?(name)
      Hash === name && String === name.keys.first && Float(name.values.first) rescue false
    end

    def key
      "#{experiment_name}:#{name}"
    end
  end
end
