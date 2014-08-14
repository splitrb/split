require 'spec_helper'
require 'split/trial'

describe Split::Trial do
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
      trial = Split::Trial.new(:experiment => experiment = double('experiment'), :alternative => alternative)
      expect(trial).not_to receive(:choose)
      expect(trial.alternative).to eq(alternative)
    end

    it "should populate alternative with a full alternative object after calling choose" do
      experiment = Split::Experiment.new('basket_text', :alternatives => ['basket', 'cart'])
      experiment.save
      trial = Split::Trial.new(:experiment => experiment)
      trial.choose
      expect(trial.alternative.class).to eq(Split::Alternative)
      expect(['basket', 'cart']).to include(trial.alternative.name)
    end

    it "should populate an alternative when only one option is offerred" do
      experiment = Split::Experiment.new('basket_text', :alternatives => ['basket'])
      experiment.save
      trial = Split::Trial.new(:experiment => experiment)
      trial.choose
      expect(trial.alternative.class).to eq(Split::Alternative)
      expect(trial.alternative.name).to eq('basket')
    end


    it "should choose from the available alternatives" do
      trial = Split::Trial.new(:experiment => experiment = double('experiment'))
      alternative = double('alternative', :kind_of? => Split::Alternative)
      expect(experiment).to receive(:next_alternative).and_return(alternative)
      expect(alternative).to receive(:increment_participation)
      expect(experiment).to receive(:winner).at_most(1).times.and_return(nil)
      trial.choose!

      expect(trial.alternative).to eq(alternative)
    end
  end

  describe "alternative_name" do
    it "should load the alternative when the alternative name is set" do
      experiment = Split::Experiment.new('basket_text', :alternatives => ['basket', "cart"])
      experiment.save

      trial = Split::Trial.new(:experiment => experiment, :alternative => 'basket')
      expect(trial.alternative.name).to eq('basket')
    end
  end
end
