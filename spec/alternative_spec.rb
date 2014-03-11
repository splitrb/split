require 'spec_helper'
require 'split/alternative'

describe Split::Alternative do

  let(:alternative) {
    Split::Alternative.new('Basket', 'basket_text')
  }

  let(:alternative2) {
    Split::Alternative.new('Cart', 'basket_text')
  }

  let!(:experiment) {
    Split::Experiment.find_or_create({"basket_text" => ["purchase", "refund"]}, "Basket", "Cart")
  }

  let(:goal1) { "purchase" }
  let(:goal2) { "refund" }

  it "should have goals" do
    alternative.goals.should eql(["purchase", "refund"])
  end

  it "should have and only return the name" do
    alternative.name.should eql('Basket')
  end

  describe 'weights' do
    it "should set the weights" do
      experiment = Split::Experiment.new('basket_text', :alternatives => [{'Basket' => 0.6}, {"Cart" => 0.4}])
      first = experiment.alternatives[0]
      first.name.should == 'Basket'
      first.weight.should == 0.6

      second = experiment.alternatives[1]
      second.name.should == 'Cart'
      second.weight.should == 0.4
    end

    it "accepts probability on alternatives" do
      Split.configuration.experiments = {
        :my_experiment => {
          :alternatives => [
            { :name => "control_opt", :percent => 67 },
            { :name => "second_opt", :percent => 10 },
            { :name => "third_opt", :percent => 23 },
          ]
        }
      }
      experiment = Split::Experiment.new(:my_experiment)
      first = experiment.alternatives[0]
      first.name.should == 'control_opt'
      first.weight.should == 0.67

      second = experiment.alternatives[1]
      second.name.should == 'second_opt'
      second.weight.should == 0.1
    end

    it "accepts probability on some alternatives" do
      Split.configuration.experiments = {
        :my_experiment => {
          :alternatives => [
            { :name => "control_opt", :percent => 34 },
            "second_opt",
            { :name => "third_opt", :percent => 23 },
            "fourth_opt",
          ],
        }
      }
      experiment = Split::Experiment.new(:my_experiment)
      alts = experiment.alternatives
      [
        ["control_opt", 0.34],
        ["second_opt", 0.215],
        ["third_opt", 0.23],
        ["fourth_opt", 0.215]
      ].each do |h|
        name, weight = h
        alt = alts.shift
        alt.name.should == name
        alt.weight.should == weight
      end
    end
    #
    it "allows name param without probability" do
      Split.configuration.experiments = {
        :my_experiment => {
          :alternatives => [
            { :name => "control_opt" },
            "second_opt",
            { :name => "third_opt", :percent => 64 },
          ],
        }
      }
      experiment = Split::Experiment.new(:my_experiment)
      alts = experiment.alternatives
      [
        ["control_opt", 0.18],
        ["second_opt", 0.18],
        ["third_opt", 0.64],
      ].each do |h|
        name, weight = h
        alt = alts.shift
        alt.name.should == name
        alt.weight.should == weight
      end
    end
  end

  it "should have a default participation count of 0" do
    alternative.participant_count.should eql(0)
  end

  it "should have a default completed count of 0 for each goal" do
    alternative.completed_count.should eql(0)
    alternative.completed_count(goal1).should eql(0)
    alternative.completed_count(goal2).should eql(0)
  end

  it "should belong to an experiment" do
    alternative.experiment.name.should eql(experiment.name)
  end

  it "should save to redis" do
    alternative.save
    Split.redis.exists('basket_text:Basket').should be true
  end

  it "should increment participation count" do
    old_participant_count = alternative.participant_count
    alternative.increment_participation
    alternative.participant_count.should eql(old_participant_count+1)
  end

  it "should increment completed count for each goal" do
    old_default_completed_count = alternative.completed_count
    old_completed_count_for_goal1 = alternative.completed_count(goal1)
    old_completed_count_for_goal2 = alternative.completed_count(goal2)

    alternative.increment_completion
    alternative.increment_completion(goal1)
    alternative.increment_completion(goal2)

    alternative.completed_count.should eql(old_default_completed_count+1)
    alternative.completed_count(goal1).should eql(old_completed_count_for_goal1+1)
    alternative.completed_count(goal2).should eql(old_completed_count_for_goal2+1)
  end

  it "can be reset" do
    alternative.participant_count = 10
    alternative.set_completed_count(4, goal1)
    alternative.set_completed_count(5, goal2)
    alternative.set_completed_count(6)
    alternative.reset
    alternative.participant_count.should eql(0)
    alternative.completed_count(goal1).should eql(0)
    alternative.completed_count(goal2).should eql(0)
    alternative.completed_count.should eql(0)
  end

  it "should know if it is the control of an experiment" do
    alternative.control?.should be_true
    alternative2.control?.should be_false
  end

  describe 'unfinished_count' do
    it "should be difference between participant and completed counts" do
      alternative.increment_participation
      alternative.unfinished_count.should eql(alternative.participant_count)
    end

    it "should return the correct unfinished_count" do
      alternative.participant_count = 10
      alternative.set_completed_count(4, goal1)
      alternative.set_completed_count(3, goal2)
      alternative.set_completed_count(2)

      alternative.unfinished_count.should eql(1)
    end
  end

  describe 'conversion rate' do
    it "should be 0 if there are no conversions" do
      alternative.completed_count.should eql(0)
      alternative.conversion_rate.should eql(0)
    end

    it "calculate conversion rate" do
      alternative.stub(:participant_count).and_return(10)
      alternative.stub(:completed_count).and_return(4)
      alternative.conversion_rate.should eql(0.4)

      alternative.stub(:completed_count).with(goal1).and_return(5)
      alternative.conversion_rate(goal1).should eql(0.5)

      alternative.stub(:completed_count).with(goal2).and_return(6)
      alternative.conversion_rate(goal2).should eql(0.6)
    end
  end

  describe 'z score' do

    it "should return an error string when the control has 0 people" do
      alternative2.z_score.should eql("Needs 30+ participants.")
      alternative2.z_score(goal1).should eql("Needs 30+ participants.")
      alternative2.z_score(goal2).should eql("Needs 30+ participants.")
    end

    it "should return an error string when the data is skewed or incomplete as per the np > 5 test" do
      control = experiment.control
      control.participant_count = 100
      control.set_completed_count(50)

      alternative2.participant_count = 50
      alternative2.set_completed_count(1)

      alternative2.z_score.should eql("Needs 5+ conversions.")
    end

    it "should return a float for a z_score given proper data" do
      control = experiment.control
      control.participant_count = 120
      control.set_completed_count(20)

      alternative2.participant_count = 100
      alternative2.set_completed_count(25)

      alternative2.z_score.should be_kind_of(Float)
      alternative2.z_score.should_not eql(0)
    end

    it "should correctly calculate a z_score given proper data" do
      control = experiment.control
      control.participant_count = 126
      control.set_completed_count(89)

      alternative2.participant_count = 142
      alternative2.set_completed_count(119)

      alternative2.z_score.round(2).should eql(2.58)
    end

    it "should be N/A for the control" do
      control = experiment.control
      control.z_score.should eql('N/A')
      control.z_score(goal1).should eql('N/A')
      control.z_score(goal2).should eql('N/A')
    end
  end
end
