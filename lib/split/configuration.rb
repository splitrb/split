module Split
  class Configuration
    BOTS = {
      'Baidu' => 'Chinese spider',
      'Gigabot' => 'Gigabot spider',
      'Googlebot' => 'Google spider',
      'libwww-perl' => 'Perl client-server library loved by script kids',
      'lwp-trivial' => 'Another Perl library loved by script kids',
      'msnbot' => 'Microsoft bot',
      'SiteUptime' => 'Site monitoring services',
      'Slurp' => 'Yahoo spider',
      'WordPress' => 'WordPress spider',
      'ZIBB' => 'ZIBB spider',
      'ZyBorg' => 'Zyborg? Hmmm....',
      "AdsBot-Google" => 'Google Adwords',
      "DigitalPersona Fingerprint Software" => 'HP Fingerprint scanner',
      "EventMachine HttpClient" => 'Ruby http library',
      "Go http package" => 'Go http library',
      "Python-urllib" => 'Python http library',
      "ShowyouBot" => 'Showyou Bot',
      "Test Certificate Info" => 'C http library?',
      "Wget" => 'wget unix CLI http client',
      "bitlybot" => 'bit.ly bot',
      "curl" => 'curl unix CLI http client',
      "facebookexternalhit" => 'facebook bot',
      "spider" => 'generic web spider',
      "Pingdom" => 'Pingdom monitoring'
    }
    attr_accessor :robot_regex
    attr_accessor :ignore_ip_addresses
    attr_accessor :db_failover
    attr_accessor :db_failover_on_db_error
    attr_accessor :db_failover_allow_parameter_override
    attr_accessor :allow_multiple_experiments
    attr_accessor :enabled
    attr_accessor :experiments
    attr_accessor :persistence
    attr_accessor :algorithm

    def disabled?
      !enabled
    end

    def experiment_for(name)
      if normalized_experiments
        # TODO symbols
        normalized_experiments[name.to_sym]
      end
    end

    def metrics
      return @metrics if defined?(@metrics)
      @metrics = {}
      if self.experiments
        self.experiments.each do |key, value|
          metric_name = value[:metric]
          if metric_name
            @metrics[metric_name] ||= []
            @metrics[metric_name] << Split::Experiment.new(key)
          end
        end
      end
      @metrics
    end

    def normalized_experiments
      if @experiments.nil?
        nil
      else
        experiment_config = {}
        @experiments.keys.each do | name |
          experiment_config[name] = {}
        end
        @experiments.each do | experiment_name, settings|
          experiment_config[experiment_name][:alternatives] = normalize_alternatives(settings[:alternatives]) if settings[:alternatives]
          experiment_config[experiment_name][:goals] = settings[:goals] if settings[:goals]
        end
        experiment_config
      end
    end

    def normalize_alternatives(alternatives)
      given_probability, num_with_probability = alternatives.inject([0,0]) do |a,v|
        p, n = a
        if v.kind_of?(Hash) && v[:percent]
          [p + v[:percent], n + 1]
        else
          a
        end
      end

      num_without_probability = alternatives.length - num_with_probability
      unassigned_probability = ((100.0 - given_probability) / num_without_probability / 100.0)

      if num_with_probability.nonzero?
        alternatives = alternatives.map do |v|
          if v.kind_of?(Hash) && v[:name] && v[:percent]
            { v[:name] => v[:percent] / 100.0 }
          elsif v.kind_of?(Hash) && v[:name]
            { v[:name] => unassigned_probability }
          else
            { v => unassigned_probability }
          end
        end
        [alternatives.shift, alternatives]
      else
        alternatives = alternatives.dup
        [alternatives.shift, alternatives]
      end
    end

    def initialize
      @robot_regex = /\b(#{BOTS.keys.join('|')})\b|^\W*$/i
      @ignore_ip_addresses = []
      @db_failover = false
      @db_failover_on_db_error = proc{|error|} # e.g. use Rails logger here
      @db_failover_allow_parameter_override = false
      @allow_multiple_experiments = false
      @enabled = true
      @experiments = {}
      @persistence = Split::Persistence::SessionAdapter
      @algorithm = Split::Algorithms::WeightedSample
    end
  end
end
