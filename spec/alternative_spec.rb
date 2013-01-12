require 'spec_helper'
require 'split/alternative'

describe Split::Alternative do

  it "should have a name" do
    experiment = Split::Experiment.new('basket_text', :alternative_names => ['Basket', "Cart"])
    alternative = Split::Alternative.new('Basket', 'basket_text')
    alternative.name.should eql('Basket')
  end

  it "return only the name" do
    experiment = Split::Experiment.new('basket_text', :alternative_names => [{'Basket' => 0.6}, {"Cart" => 0.4}])
    alternative = Split::Alternative.new('Basket', 'basket_text')
    alternative.name.should eql('Basket')
  end
  
  describe 'weights' do
  
    it "should set the weights" do
      experiment = Split::Experiment.new('basket_text', :alternative_names => [{'Basket' => 0.6}, {"Cart" => 0.4}])
      first = experiment.alternatives[0]
      first.name.should == 'Basket'
      first.weight.should == 0.6
    
      second = experiment.alternatives[1]
      second.name.should == 'Cart'
      second.weight.should == 0.4  
    end
    
    it "accepts probability on variants" do
      Split.configuration.experiments = {
        :my_experiment => {
          :variants => [
            { :name => "control_opt", :percent => 67 },
            { :name => "second_opt", :percent => 10 },
            { :name => "third_opt", :percent => 23 },
          ],
        }
      }
      experiment = Split::Experiment.find(:my_experiment)
      first = experiment.alternatives[0]
      first.name.should == 'control_opt'
      first.weight.should == 0.67
    
      second = experiment.alternatives[1]
      second.name.should == 'second_opt'
      second.weight.should == 0.1
    end
  
    # it "accepts probability on some variants" do
    #   Split.configuration.experiments[:my_experiment] = {
    #     :variants => [
    #       { :name => "control_opt", :percent => 34 },
    #       "second_opt",
    #       { :name => "third_opt", :percent => 23 },
    #       "fourth_opt",
    #     ],
    #   }
    #   should start_experiment(:my_experiment).with({"control_opt" => 0.34}, {"second_opt" => 0.215}, {"third_opt" => 0.23}, {"fourth_opt" => 0.215})
    #   ab_test :my_experiment
    # end
    #   
    # it "allows name param without probability" do
    #   Split.configuration.experiments[:my_experiment] = {
    #     :variants => [
    #       { :name => "control_opt" },
    #       "second_opt",
    #       { :name => "third_opt", :percent => 64 },
    #     ],
    #   }
    #   should start_experiment(:my_experiment).with({"control_opt" => 0.18}, {"second_opt" => 0.18}, {"third_opt" => 0.64})
    #   ab_test :my_experiment
    # end
  
    it "should set the weights from a configuration file" do
    
    end
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
    experiment = Split::Experiment.new('basket_text', :alternative_names => ['Basket', "Cart"])
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
    experiment = Split::Experiment.new('basket_text', :alternative_names => ['Basket', "Cart"])
    experiment.save
    alternative = Split::Alternative.new('Basket', 'basket_text')
    old_participant_count = alternative.participant_count
    alternative.increment_participation
    alternative.participant_count.should eql(old_participant_count+1)

    Split::Alternative.new('Basket', 'basket_text').participant_count.should eql(old_participant_count+1)
  end

  it "should increment completed count" do
    experiment = Split::Experiment.new('basket_text', :alternative_names => ['Basket', "Cart"])
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
    experiment = Split::Experiment.new('basket_text', :alternative_names => ['Basket', "Cart"])
    experiment.save
    alternative = Split::Alternative.new('Basket', 'basket_text')
    alternative.control?.should be_true
    alternative = Split::Alternative.new('Cart', 'basket_text')
    alternative.control?.should be_false
  end

  describe 'unfinished_count' do
    it "should be difference between participant and completed counts" do
      experiment = Split::Experiment.new('basket_text', :alternative_names => ['Basket', "Cart"])
      experiment.save
      alternative = Split::Alternative.new('Basket', 'basket_text')
      alternative.increment_participation
      alternative.unfinished_count.should eql(alternative.participant_count)
    end
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