module Split
  class Configuration
    attr_accessor :robot_regex
    attr_accessor :ignore_ip_addresses

    def initialize
      @robot_regex = /\b(Baidu|Gigabot|Googlebot|libwww-perl|lwp-trivial|msnbot|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)\b/i
      @ignore_ip_addresses = []
    end
  end
end
