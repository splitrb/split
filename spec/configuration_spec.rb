require 'spec_helper'

describe Split::Configuration do
  it "should provide default values" do
    config = Split::Configuration.new

    config.robot_regex.should eql(/\b(Baidu|Gigabot|Googlebot|libwww-perl|lwp-trivial|msnbot|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)\b/i)
  end
end