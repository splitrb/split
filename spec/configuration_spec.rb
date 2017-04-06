require 'spec_helper'

describe Split::Configuration do

  before(:each) { @config = Split::Configuration.new }

  it "should provide a default value for ignore_ip_addresses" do
    @config.ignore_ip_addresses.should eql([])
  end

  it "should provide default values for db failover" do
    @config.db_failover.should be_false
    @config.db_failover_on_db_error.should be_a Proc
  end

  it "should not allow multiple experiments by default" do
    @config.allow_multiple_experiments.should be_false
  end

  it "should be enabled by default" do
    @config.enabled.should be_true
  end

  it "disabled is the opposite of enabled" do
    @config.enabled = false
    @config.disabled?.should be_true
  end

  it "should provide a default pattern for robots" do
    %w[Baidu Gigabot Googlebot libwww-perl lwp-trivial msnbot SiteUptime Slurp WordPress ZIBB ZyBorg YandexBot AdsBot-Google Wget curl bitlybot facebookexternalhit spider].each do |robot|
      @config.robot_regex.should =~ robot
    end

    @config.robot_regex.should =~ "EventMachine HttpClient"
    @config.robot_regex.should =~ "libwww-perl/5.836"
    @config.robot_regex.should =~ "Pingdom.com_bot_version_1.4_(http://www.pingdom.com)"

    @config.robot_regex.should =~ " - "
  end

  it "should accept real UAs with the robot regexp" do
    @config.robot_regex.should_not =~ "Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US; rv:1.9.1.4) Gecko/20091017 SeaMonkey/2.0"
    @config.robot_regex.should_not =~ "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; F-6.0SP2-20041109; .NET CLR 2.0.50727; .NET CLR 3.0.04506.648; .NET CLR 3.5.21022; .NET CLR 1.1.4322; InfoPath.3)"
  end

  it "should allow adding a bot to the bot list" do
    @config.bots["newbot"] = "An amazing test bot"
    @config.robot_regex.should =~ "newbot"
  end

  it "should load a metric" do
    @config.experiments = {:my_experiment=>
        {:alternatives=>["control_opt", "other_opt"], :metric=>:my_metric}}

    @config.metrics.should_not be_nil
    @config.metrics.keys.should ==  [:my_metric]
  end

  it "should allow loading of experiment using experment_for" do
    @config.experiments = {:my_experiment=>
        {:alternatives=>["control_opt", "other_opt"], :metric=>:my_metric}}
    @config.experiment_for(:my_experiment).should == {:alternatives=>["control_opt", ["other_opt"]]}
  end

  context "when experiments are defined via YAML" do
    context "as strings" do
      context "in a basic configuration" do
        before do
          experiments_yaml = <<-eos
            my_experiment:
              alternatives:
                - Control Opt
                - Alt One
                - Alt Two
              resettable: false
            eos
          @config.experiments = YAML.load(experiments_yaml)
        end

        it 'should normalize experiments' do
          @config.normalized_experiments.should == {:my_experiment=>{:resettable=>false,:alternatives=>["Control Opt", ["Alt One", "Alt Two"]]}}
        end
      end

      context "in a complex configuration" do
        before do
          experiments_yaml = <<-eos
            my_experiment:
              alternatives:
                - name: Control Opt
                  percent: 67
                - name: Alt One
                  percent: 10
                - name: Alt Two
                  percent: 23
              resettable: false
              metric: my_metric
            another_experiment:
              alternatives:
                - a
                - b
            eos
          @config.experiments = YAML.load(experiments_yaml)
        end

        it "should normalize experiments" do
          @config.normalized_experiments.should == {:my_experiment=>{:resettable=>false,:alternatives=>[{"Control Opt"=>0.67},
            [{"Alt One"=>0.1}, {"Alt Two"=>0.23}]]}, :another_experiment=>{:alternatives=>["a", ["b"]]}}
        end

        it "should recognize metrics" do
          @config.metrics.should_not be_nil
          @config.metrics.keys.should ==  [:my_metric]
        end
      end
    end

    context "as symbols" do

      context "with valid YAML" do
        before do
          experiments_yaml = <<-eos
            :my_experiment:
              :alternatives:
                - Control Opt
                - Alt One
                - Alt Two
              :resettable: false
            eos
          @config.experiments = YAML.load(experiments_yaml)
        end

        it "should normalize experiments" do
          @config.normalized_experiments.should == {:my_experiment=>{:resettable=>false,:alternatives=>["Control Opt", ["Alt One", "Alt Two"]]}}
        end
      end

      context "with invalid YAML" do

        let(:yaml) { YAML.load(input) }

        context "with an empty string" do
          let(:input) { '' }

          it "should raise an error" do
            expect { @config.experiments = yaml }.to raise_error
          end
        end

        context "with just the YAML header" do
          let(:input) { '---' }

          it "should raise an error" do
            expect { @config.experiments = yaml }.to raise_error
          end
        end
      end
    end
  end

  it "should normalize experiments" do
    @config.experiments = {
      :my_experiment => {
        :alternatives => [
          { :name => "control_opt", :percent => 67 },
          { :name => "second_opt", :percent => 10 },
          { :name => "third_opt", :percent => 23 },
        ],
      }
    }

    @config.normalized_experiments.should == {:my_experiment=>{:alternatives=>[{"control_opt"=>0.67}, [{"second_opt"=>0.1}, {"third_opt"=>0.23}]]}}
  end
end
