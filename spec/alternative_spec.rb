require 'spec_helper'
require 'split/alternative'

describe Split::Alternative do
  before(:each) { Split.redis.flushall }

  it "should have a name" do
    experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
    alternative = Split::Alternative.new('Basket', 'basket_text')
    alternative.name.should eql('Basket')
  end

  it "return only the name" do
    experiment = Split::Experiment.new('basket_text', {'Basket' => 0.6}, {"Cart" => 0.4})
    alternative = Split::Alternative.new('Basket', 'basket_text')
    alternative.name.should eql('Basket')
  end

  it "should have a default participation count of 0" do
    alternative = Split::Alternative.new('Basket', 'basket_text')
    alternative.participant_count.should eql(0)
  end

  it "should have a default completed count of 0" do
    alternative = Split::Alternative.new('Basket', 'basket_text')
    alternative.completed_count.should eql(0)
  end

  it "should belong to an experiment" do
    experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.save
    alternative = Split::Alternative.new('Basket', 'basket_text')
    alternative.experiment.name.should eql(experiment.name)
  end

  it "should save to redis" do
    alternative = Split::Alternative.new('Basket', 'basket_text')
    alternative.save
    Split.redis.exists('basket_text:Basket').should be true
  end

  it "should increment participation count" do
    experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.save
    alternative = Split::Alternative.new('Basket', 'basket_text')
    old_participant_count = alternative.participant_count
    alternative.increment_participation
    alternative.participant_count.should eql(old_participant_count+1)

    Split::Alternative.new('Basket', 'basket_text').participant_count.should eql(old_participant_count+1)
  end

  it "should increment completed count" do
    experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.save
    alternative = Split::Alternative.new('Basket', 'basket_text')
    old_completed_count = alternative.participant_count
    alternative.increment_completion
    alternative.completed_count.should eql(old_completed_count+1)

    Split::Alternative.new('Basket', 'basket_text').completed_count.should eql(old_completed_count+1)
  end

  it "can be reset" do
    alternative = Split::Alternative.new('Basket', 'basket_text')
    alternative.participant_count = 10
    alternative.completed_count = 4
    alternative.reset
    alternative.participant_count.should eql(0)
    alternative.completed_count.should eql(0)
  end

  it "should know if it is the control of an experiment" do
    experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.save
    alternative = Split::Alternative.new('Basket', 'basket_text')
    alternative.control?.should be_true
    alternative = Split::Alternative.new('Cart', 'basket_text')
    alternative.control?.should be_false
  end

  describe 'conversion rate' do
    it "should be 0 if there are no conversions" do
      alternative = Split::Alternative.new('Basket', 'basket_text')
      alternative.completed_count.should eql(0)
      alternative.conversion_rate.should eql(0)
    end

    it "calculate conversion rate" do
      alternative = Split::Alternative.new('Basket', 'basket_text')
      alternative.stub(:participant_count).and_return(10)
      alternative.stub(:completed_count).and_return(4)
      alternative.conversion_rate.should eql(0.4)
    end
  end

  describe 'z score' do
    it 'should be zero when the control has no conversions' do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')

      alternative = Split::Alternative.new('red', 'link_color')
      alternative.z_score.should eql(0)
    end

    it "should be N/A for the control" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')

      control = experiment.control
      control.z_score.should eql('N/A')
    end
  end
end