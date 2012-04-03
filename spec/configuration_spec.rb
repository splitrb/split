require 'spec_helper'

describe Split::Configuration do
  it "should provide default values" do
    config = Split::Configuration.new

    config.ignore_ip_addresses.should eql([])
    config.robot_regex.should eql(/\b(Baidu|Gigabot|Googlebot|libwww-perl|lwp-trivial|msnbot|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)\b/i)
    config.db_failover.should be_false
    config.db_failover_on_db_error.should be_a Proc
    config.allow_multiple_experiments.should be_false
    config.enabled.should be_true
  end
end
