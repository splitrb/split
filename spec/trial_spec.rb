require 'spec_helper'
require 'split/trial'

describe Split::Trial do
  let(:user) { Split::Persistence.adapter.new(double(session: {})) }
  let(:experiment) do
    Split::Experiment.new('basket_text', :alternatives => ['basket', 'cart']).save
  end

  it "should be initializeable" do
    experiment  = double('experiment')
    alternative = double('alternative', :kind_of? => Split::Alternative)
    trial = Split::Trial.new(:experiment => experiment, :alternative => alternative)
    expect(trial.experiment).to eq(experiment)
    expect(trial.alternative).to eq(alternative)
    expect(trial.goals).to eq([])
  end

  describe "alternative" do
    it "should use the alternative if specified" do
      alternative = double('alternative', :kind_of? => Split::Alternative)
      trial = Split::Trial.new(:experiment => experiment = double('experiment'),
          :alternative => alternative, :user => user)
      expect(trial).not_to receive(:choose)
      expect(trial.alternative).to eq(alternative)
    end

    it "should load the alternative when the alternative name is set" do
      experiment = Split::Experiment.new('basket_text', :alternatives => ['basket', 'cart'])
      experiment.save

      trial = Split::Trial.new(:experiment => experiment, :alternative => 'basket')
      expect(trial.alternative.name).to eq('basket')
    end
  end

  describe "#choose" do
    def expect_alternative(trial, alternative_name)
      3.times do
        trial.choose
        expect(trial.alternative.name).to eq(alternative_name)
      end
    end

    context "when override is present" do
      it "picks the override" do
        trial = Split::Trial.new(:user => user, :experiment => experiment, :override => 'cart')
        expect(experiment).to_not receive(:next_alternative)

        expect_alternative(trial, 'cart')
      end
    end

    context "when disabled" do
      it "picks the control" do
        trial = Split::Trial.new(:user => user, :experiment => experiment, :disabled => true)
        expect(experiment).to_not receive(:next_alternative)

        expect_alternative(trial, 'basket')
      end
    end

    context "experiment has winner" do
      it "picks the winner" do
        trial = Split::Trial.new(:user => user, :experiment => experiment)
        experiment.winner = 'cart'
        expect(experiment).to_not receive(:next_alternative)

        expect_alternative(trial, 'cart')
      end
    end

    context "when exclude is true" do
      it "picks the control" do
        trial = Split::Trial.new(:user => user, :experiment => experiment, :exclude => true)
        expect(experiment).to_not receive(:next_alternative)

        expect_alternative(trial, 'basket')
      end
    end

    context "when user is already participating" do
      it "picks the same alternative" do
        user[experiment.key] = 'basket'
        trial = Split::Trial.new(:user => user, :experiment => experiment)
        expect(experiment).to_not receive(:next_alternative)

        expect_alternative(trial, 'basket')
      end
    end

    context "when user is a new participant" do
      it "picks a new alternative" do
        trial = Split::Trial.new(:user => user, :experiment => experiment)
        expect(experiment).to receive(:next_alternative).and_call_original

        trial.choose
        expect(trial.alternative.name).to_not be_empty
      end
    end
  end

  describe "#record!" do
    before(:each) { Split.configuration.store_override = false }

    context "when override is present" do
      it "stores when store_override is true" do
        trial = Split::Trial.new(:user => user, :experiment => experiment, :override => 'basket')
        trial.choose

        Split.configuration.store_override = true
        expect(user).to receive("[]=")
        trial.record!
      end

      it "does not store when store_override is false" do
        trial = Split::Trial.new(:user => user, :experiment => experiment, :override => 'basket')
        trial.choose

        expect(user).to_not receive("[]=")
        trial.record!
      end
    end

    context "when disabled is present" do
      it "stores when store_override is true" do
        trial = Split::Trial.new(:user => user, :experiment => experiment, :disabled => true)
        trial.choose

        Split.configuration.store_override = true
        expect(user).to receive("[]=")
        trial.record!
      end

      it "does not store when store_override is false" do
        trial = Split::Trial.new(:user => user, :experiment => experiment, :disabled => true)
        trial.choose

        expect(user).to_not receive("[]=")
        trial.record!
      end
    end

    context "when exclude is present" do
      it "does not store" do
        trial = Split::Trial.new(:user => user, :experiment => experiment, :exclude => true)
        trial.choose

        expect(user).to_not receive("[]=")
        trial.record!
      end
    end
  end
end
