module Split
  class Configuration
    attr_accessor :robot_regex

    def initialize()
      @robot_regex = /\b(Baidu|Gigabot|Googlebot|libwww-perl|lwp-trivial|msnbot|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)\b/i
    end
  end
end
