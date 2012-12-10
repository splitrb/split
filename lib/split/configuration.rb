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
      'ZyBorg' => 'Zyborg? Hmmm....'
    }
    attr_accessor :robot_regex
    attr_accessor :ignore_ip_addresses
    attr_accessor :db_failover
    attr_accessor :db_failover_on_db_error
    attr_accessor :db_failover_allow_parameter_override
    attr_accessor :allow_multiple_experiments
    attr_accessor :enabled
    attr_accessor :persistence

    def initialize
      @robot_regex = /\b(#{BOTS.keys.join('|')})\b/i
      @ignore_ip_addresses = []
      @db_failover = false
      @db_failover_on_db_error = proc{|error|} # e.g. use Rails logger here
      @db_failover_allow_parameter_override = false
      @allow_multiple_experiments = false
      @enabled = true
      @persistence = Split::Persistence::SessionAdapter
    end
  end
end
