require 'spec_helper'

describe Split::Configuration do

  before(:each) { @config = Split::Configuration.new }

  it "should provide a default value for ignore_ip_addresses" do
    expect(@config.ignore_ip_addresses).to eq([])
  end

  it "should provide default values for db failover" do
    expect(@config.db_failover).to be_falsey
    expect(@config.db_failover_on_db_error).to be_a Proc
  end

  it "should not allow multiple experiments by default" do
    expect(@config.allow_multiple_experiments).to be_falsey
  end

  it "should be enabled by default" do
    expect(@config.enabled).to be_truthy
  end

  it "disabled is the opposite of enabled" do
    @config.enabled = false
    expect(@config.disabled?).to be_truthy
  end

  it "should not store the overridden test group per default" do
    expect(@config.store_override).to be_falsey
  end

  it "should provide a default pattern for robots" do
    %w[Baidu Gigabot Googlebot libwww-perl lwp-trivial msnbot SiteUptime Slurp WordPress ZIBB ZyBorg YandexBot AdsBot-Google Wget curl bitlybot facebookexternalhit spider].each do |robot|
      expect(@config.robot_regex).to match(robot)
    end

    expect(@config.robot_regex).to match("EventMachine HttpClient")
    expect(@config.robot_regex).to match("libwww-perl/5.836")
    expect(@config.robot_regex).to match("Pingdom.com_bot_version_1.4_(http://www.pingdom.com)")

    expect(@config.robot_regex).to match(" - ")
  end

  it "should accept real UAs with the robot regexp" do
    expect(@config.robot_regex).not_to match("Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US; rv:1.9.1.4) Gecko/20091017 SeaMonkey/2.0")
    expect(@config.robot_regex).not_to match("Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; F-6.0SP2-20041109; .NET CLR 2.0.50727; .NET CLR 3.0.04506.648; .NET CLR 3.5.21022; .NET CLR 1.1.4322; InfoPath.3)")
  end

  it "should allow adding a bot to the bot list" do
    @config.bots["newbot"] = "An amazing test bot"
    expect(@config.robot_regex).to match("newbot")
  end

  it "should use the session adapter for persistence by default" do
    expect(@config.persistence).to eq(Split::Persistence::SessionAdapter)
  end

  it "should load a metric" do
    @config.experiments = {:my_experiment=>
        {:alternatives=>["control_opt", "other_opt"], :metric=>:my_metric}}

    expect(@config.metrics).not_to be_nil
    expect(@config.metrics.keys).to eq([:my_metric])
  end

  it "should allow loading of experiment using experment_for" do
    @config.experiments = {:my_experiment=>
        {:alternatives=>["control_opt", "other_opt"], :metric=>:my_metric}}
    expect(@config.experiment_for(:my_experiment)).to eq({:alternatives=>["control_opt", ["other_opt"]]})
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
          expect(@config.normalized_experiments).to eq({:my_experiment=>{:resettable=>false,:alternatives=>["Control Opt", ["Alt One", "Alt Two"]]}})
        end
      end

      context "in a configuration with metadata" do
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
              metadata:
                Control Opt:
                  text: 'Control Option'
                Alt One:
                  text: 'Alternative One'
                Alt Two:
                  text: 'Alternative Two'
              resettable: false
            eos
          @config.experiments = YAML.load(experiments_yaml)
        end

        it 'should have metadata on the experiment' do
          meta = @config.normalized_experiments[:my_experiment][:metadata]
          expect(meta).to_not be nil
          expect(meta['Control Opt']['text']).to eq('Control Option')
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
          expect(@config.normalized_experiments).to eq({:my_experiment=>{:resettable=>false,:alternatives=>[{"Control Opt"=>0.67},
            [{"Alt One"=>0.1}, {"Alt Two"=>0.23}]]}, :another_experiment=>{:alternatives=>["a", ["b"]]}})
        end

        it "should recognize metrics" do
          expect(@config.metrics).not_to be_nil
          expect(@config.metrics.keys).to eq([:my_metric])
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
          expect(@config.normalized_experiments).to eq({:my_experiment=>{:resettable=>false,:alternatives=>["Control Opt", ["Alt One", "Alt Two"]]}})
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

    expect(@config.normalized_experiments).to eq({:my_experiment=>{:alternatives=>[{"control_opt"=>0.67}, [{"second_opt"=>0.1}, {"third_opt"=>0.23}]]}})
  end
end
