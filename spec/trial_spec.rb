require 'spec_helper'
require 'split/trial'

describe Split::Trial do
  it "should be initializeable" do
    experiment  = mock('experiment')
    alternative = mock('alternative')
    trial = Split::Trial.new(experiment: experiment, alternative: alternative)
    trial.experiment.should == experiment
    trial.alternative.should == alternative
  end

  describe "alternative" do
    it "should use the alternative if specified" do
      trial = Split::Trial.new(experiment: experiment = mock('experiment'), alternative: alternative = mock('alternative'))
      trial.should_not_receive(:choose)
      trial.alternative.should == alternative
    end

    it "should call select_alternative if nil" do
      trial = Split::Trial.new(experiment: experiment = mock('experiment'))
      trial.should_receive(:choose).and_return(alternative = mock('alternative'))
      trial.choose!

      trial.alternative.should == alternative
    end
  end

  describe "alternative_name" do
    it "should load the alternative when the alternative name is set" do
      experiment = Split::Experiment.new('basket_text', 'basket', 'cart')
      experiment.save

      trial = Split::Trial.new(experiment: experiment, alternative_name: 'basket')
      trial.alternative.name.should == 'basket'
    end
  end
end
