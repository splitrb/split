module Split
  class Configuration
    attr_accessor :bots
    attr_accessor :robot_regex
    attr_accessor :ignore_ip_addresses
    attr_accessor :ignore_filter
    attr_accessor :db_failover
    attr_accessor :db_failover_on_db_error
    attr_accessor :db_failover_allow_parameter_override
    attr_accessor :allow_multiple_experiments
    attr_accessor :enabled
    attr_accessor :persistence
    attr_accessor :algorithm
    attr_accessor :store_override
    attr_accessor :start_manually
    attr_accessor :on_trial_choose
    attr_accessor :on_trial_complete
    attr_accessor :on_experiment_reset
    attr_accessor :on_experiment_delete
    attr_accessor :include_rails_helper
    attr_accessor :beta_probability_simulations

    attr_reader :experiments

    def bots
      @bots ||= {
        # Indexers
        'AdsBot-Google' => 'Google Adwords',
        'Baidu' => 'Chinese search engine',
        'Baiduspider' => 'Chinese search engine',
        'bingbot' => 'Microsoft bing bot',
        'Butterfly' => 'Topsy Labs',
        'Gigabot' => 'Gigabot spider',
        'Googlebot' => 'Google spider',
        'MJ12bot' => 'Majestic-12 spider',
        'msnbot' => 'Microsoft bot',
        'rogerbot' => 'SeoMoz spider',
        'PaperLiBot' => 'PaperLi is another content curation service',
        'Slurp' => 'Yahoo spider',
        'Sogou' => 'Chinese search engine',
        'spider' => 'generic web spider',
        'UnwindFetchor' => 'Gnip crawler',
        'WordPress' => 'WordPress spider',
        'YandexBot' => 'Yandex spider',
        'ZIBB' => 'ZIBB spider',

        # HTTP libraries
        'Apache-HttpClient' => 'Java http library',
        'AppEngine-Google' => 'Google App Engine',
        'curl' => 'curl unix CLI http client',
        'ColdFusion' => 'ColdFusion http library',
        'EventMachine HttpClient' => 'Ruby http library',
        'Go http package' => 'Go http library',
        'Java' => 'Generic Java http library',
        'libwww-perl' => 'Perl client-server library loved by script kids',
        'lwp-trivial' => 'Another Perl library loved by script kids',
        'Python-urllib' => 'Python http library',
        'PycURL' => 'Python http library',
        'Test Certificate Info' => 'C http library?',
        'Wget' => 'wget unix CLI http client',

        # URL expanders / previewers
        'awe.sm' => 'Awe.sm URL expander',
        'bitlybot' => 'bit.ly bot',
        'bot@linkfluence.net' => 'Linkfluence bot',
        'facebookexternalhit' => 'facebook bot',
        'Feedfetcher-Google' => 'Google Feedfetcher',
        'https://developers.google.com/+/web/snippet' => 'Google+ Snippet Fetcher',
        'LongURL' => 'URL expander service',
        'NING' => 'NING - Yet Another Twitter Swarmer',
        'redditbot' => 'Reddit Bot',
        'ShortLinkTranslate' => 'Link shortener',
        'TweetmemeBot' => 'TweetMeMe Crawler',
        'Twitterbot' => 'Twitter URL expander',
        'UnwindFetch' => 'Gnip URL expander',
        'vkShare' => 'VKontake Sharer',

        # Uptime monitoring
        'check_http' => 'Nagios monitor',
        'NewRelicPinger' => 'NewRelic monitor',
        'Panopta' => 'Monitoring service',
        'Pingdom' => 'Pingdom monitoring',
        'SiteUptime' => 'Site monitoring services',

        # ???
        'DigitalPersona Fingerprint Software' => 'HP Fingerprint scanner',
        'ShowyouBot' => 'Showyou iOS app spider',
        'ZyBorg' => 'Zyborg? Hmmm....',
        'ELB-HealthChecker' => 'ELB Health Check'
      }
    end

    def experiments= experiments
      raise InvalidExperimentsFormatError.new('Experiments must be a Hash') unless experiments.respond_to?(:keys)
      @experiments = experiments
    end

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
          metrics = value_for(value, :metric) rescue nil
          Array(metrics).each do |metric_name|
            if metric_name
              @metrics[metric_name.to_sym] ||= []
              @metrics[metric_name.to_sym] << Split::Experiment.new(key)
            end
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
        @experiments.keys.each do |name|
          experiment_config[name.to_sym] = {}
        end

        @experiments.each do |experiment_name, settings|
          if alternatives = value_for(settings, :alternatives)
            experiment_config[experiment_name.to_sym][:alternatives] = normalize_alternatives(alternatives)
          end

          if goals = value_for(settings, :goals)
            experiment_config[experiment_name.to_sym][:goals] = goals
          end

          if metadata = value_for(settings, :metadata)
            experiment_config[experiment_name.to_sym][:metadata] = metadata
          end

          if (resettable = value_for(settings, :resettable)) != nil
            experiment_config[experiment_name.to_sym][:resettable] = resettable
          end
        end

        experiment_config
      end
    end

    def normalize_alternatives(alternatives)
      given_probability, num_with_probability = alternatives.inject([0,0]) do |a,v|
        p, n = a
        if percent = value_for(v, :percent)
          [p + percent, n + 1]
        else
          a
        end
      end

      num_without_probability = alternatives.length - num_with_probability
      unassigned_probability = ((100.0 - given_probability) / num_without_probability / 100.0)

      if num_with_probability.nonzero?
        alternatives = alternatives.map do |v|
          if (name = value_for(v, :name)) && (percent = value_for(v, :percent))
            { name => percent / 100.0 }
          elsif name = value_for(v, :name)
            { name => unassigned_probability }
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

    def robot_regex
      @robot_regex ||= /\b(?:#{escaped_bots.join('|')})\b|\A\W*\z/i
    end

    def initialize
      @ignore_ip_addresses = []
      @ignore_filter = proc{ |request| is_robot? || is_ignored_ip_address? }
      @db_failover = false
      @db_failover_on_db_error = proc{|error|} # e.g. use Rails logger here
      @on_experiment_reset = proc{|experiment|}
      @on_experiment_delete = proc{|experiment|}
      @db_failover_allow_parameter_override = false
      @allow_multiple_experiments = false
      @enabled = true
      @experiments = {}
      @persistence = Split::Persistence::SessionAdapter
      @algorithm = Split::Algorithms::WeightedSample
      @include_rails_helper = true
      @beta_probability_simulations = 10000
    end

    private

    def value_for(hash, key)
      if hash.kind_of?(Hash)
        hash.has_key?(key.to_s) ? hash[key.to_s] : hash[key.to_sym]
      end
    end

    def escaped_bots
      bots.map { |key, _| Regexp.escape(key) }
    end
  end
end
