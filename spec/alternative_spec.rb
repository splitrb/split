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
    Split::ExperimentCatalog.find_or_create({"basket_text" => ["purchase", "refund"]}, "Basket", "Cart")
  }

  let(:goal1) { "purchase" }
  let(:goal2) { "refund" }

  it "should have goals" do
    expect(alternative.goals).to eq(["purchase", "refund"])
  end

  it "should have and only return the name" do
    expect(alternative.name).to eq('Basket')
  end

  describe 'weights' do
    it "should set the weights" do
      experiment = Split::Experiment.new('basket_text', :alternatives => [{'Basket' => 0.6}, {"Cart" => 0.4}])
      first = experiment.alternatives[0]
      expect(first.name).to eq('Basket')
      expect(first.weight).to eq(0.6)

      second = experiment.alternatives[1]
      expect(second.name).to eq('Cart')
      expect(second.weight).to eq(0.4)
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
      expect(first.name).to eq('control_opt')
      expect(first.weight).to eq(0.67)

      second = experiment.alternatives[1]
      expect(second.name).to eq('second_opt')
      expect(second.weight).to eq(0.1)
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
        expect(alt.name).to eq(name)
        expect(alt.weight).to eq(weight)
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
        expect(alt.name).to eq(name)
        expect(alt.weight).to eq(weight)
      end
    end
  end

  it "should have a default participation count of 0" do
    expect(alternative.participant_count).to eq(0)
  end

  it "should have a default completed count of 0 for each goal" do
    expect(alternative.completed_count).to eq(0)
    expect(alternative.completed_count(goal1)).to eq(0)
    expect(alternative.completed_count(goal2)).to eq(0)
  end

  it "should belong to an experiment" do
    expect(alternative.experiment.name).to eq(experiment.name)
  end

  it "should save to redis" do
    alternative.save
    expect(Split.redis.exists('basket_text:Basket')).to be true
  end

  it "should increment participation count" do
    old_participant_count = alternative.participant_count
    alternative.increment_participation
    expect(alternative.participant_count).to eq(old_participant_count+1)
  end

  it "should increment completed count for each goal" do
    old_default_completed_count = alternative.completed_count
    old_completed_count_for_goal1 = alternative.completed_count(goal1)
    old_completed_count_for_goal2 = alternative.completed_count(goal2)

    alternative.increment_completion
    alternative.increment_completion(goal1)
    alternative.increment_completion(goal2)

    expect(alternative.completed_count).to eq(old_default_completed_count+1)
    expect(alternative.completed_count(goal1)).to eq(old_completed_count_for_goal1+1)
    expect(alternative.completed_count(goal2)).to eq(old_completed_count_for_goal2+1)
  end

  it "can be reset" do
    alternative.participant_count = 10
    alternative.set_completed_count(4, goal1)
    alternative.set_completed_count(5, goal2)
    alternative.set_completed_count(6)
    alternative.reset
    expect(alternative.participant_count).to eq(0)
    expect(alternative.completed_count(goal1)).to eq(0)
    expect(alternative.completed_count(goal2)).to eq(0)
    expect(alternative.completed_count).to eq(0)
  end

  it "should know if it is the control of an experiment" do
    expect(alternative.control?).to be_truthy
    expect(alternative2.control?).to be_falsey
  end

  describe 'unfinished_count' do
    it "should be difference between participant and completed counts" do
      alternative.increment_participation
      expect(alternative.unfinished_count).to eq(alternative.participant_count)
    end

    it "should return the correct unfinished_count" do
      alternative.participant_count = 10
      alternative.set_completed_count(4, goal1)
      alternative.set_completed_count(3, goal2)
      alternative.set_completed_count(2)

      expect(alternative.unfinished_count).to eq(1)
    end
  end

  describe 'conversion rate' do
    it "should be 0 if there are no conversions" do
      expect(alternative.completed_count).to eq(0)
      expect(alternative.conversion_rate).to eq(0)
    end

    it "calculate conversion rate" do
      expect(alternative).to receive(:participant_count).exactly(6).times.and_return(10)
      expect(alternative).to receive(:completed_count).and_return(4)
      expect(alternative.conversion_rate).to eq(0.4)

      expect(alternative).to receive(:completed_count).with(goal1).and_return(5)
      expect(alternative.conversion_rate(goal1)).to eq(0.5)

      expect(alternative).to receive(:completed_count).with(goal2).and_return(6)
      expect(alternative.conversion_rate(goal2)).to eq(0.6)
    end
  end

  describe "probability winner" do
    before do
      experiment.calc_winning_alternatives
    end

    it "should have a probability of being the winning alternative (p_winner)" do
      expect(alternative.p_winner).not_to be_nil
    end

    it "should have a probability of being the winner for each goal" do
      expect(alternative.p_winner(goal1)).not_to be_nil
    end

    it "should be possible to set the p_winner" do
      alternative.set_p_winner(0.5)
      expect(alternative.p_winner).to eq(0.5)
    end

    it "should be possible to set the p_winner for each goal" do
      alternative.set_p_winner(0.5, goal1)
      expect(alternative.p_winner(goal1)).to eq(0.5)
    end
  end

  describe 'z score' do

    it "should return an error string when the control has 0 people" do
      expect(alternative2.z_score).to eq("Needs 30+ participants.")
      expect(alternative2.z_score(goal1)).to eq("Needs 30+ participants.")
      expect(alternative2.z_score(goal2)).to eq("Needs 30+ participants.")
    end

    it "should return an error string when the data is skewed or incomplete as per the np > 5 test" do
      control = experiment.control
      control.participant_count = 100
      control.set_completed_count(50)

      alternative2.participant_count = 50
      alternative2.set_completed_count(1)

      expect(alternative2.z_score).to eq("Needs 5+ conversions.")
    end

    it "should return a float for a z_score given proper data" do
      control = experiment.control
      control.participant_count = 120
      control.set_completed_count(20)

      alternative2.participant_count = 100
      alternative2.set_completed_count(25)

      expect(alternative2.z_score).to be_kind_of(Float)
      expect(alternative2.z_score).to_not eq(0)
    end

    it "should correctly calculate a z_score given proper data" do
      control = experiment.control
      control.participant_count = 126
      control.set_completed_count(89)

      alternative2.participant_count = 142
      alternative2.set_completed_count(119)

      expect(alternative2.z_score.round(2)).to eq(2.58)
    end

    it "should be N/A for the control" do
      control = experiment.control
      expect(control.z_score).to eq('N/A')
      expect(control.z_score(goal1)).to eq('N/A')
      expect(control.z_score(goal2)).to eq('N/A')
    end
  end
end
