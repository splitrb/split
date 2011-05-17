require 'spec_helper'
require 'split/experiment'

describe Split::Experiment do
  before(:each) { Split.redis.flushall }

  it "should have a name" do
    experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.name.should eql('basket_text')
  end
  
  it "should have alternatives" do
    experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.alternatives.length.should be 2
  end
  
  it "should save to redis" do
    experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.save
    Split.redis.exists('basket_text').should be true
  end
  
  it "should return an existing experiment" do
    experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.save
    Split::Experiment.find('basket_text').name.should eql('basket_text')
  end

  describe 'winner' do
    it "should have no winner initially" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
      experiment.winner.should be_nil
    end

    it "should allow you to specify a winner" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
      experiment.winner = 'red'

      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
      experiment.winner.name.should == 'red'
    end
  end

  describe 'next_alternative' do
    it "should return a random alternative from those with the least participants" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')

      Split::Alternative.find('blue', 'link_color').increment_participation
      Split::Alternative.find('red', 'link_color').increment_participation

      experiment.next_alternative.name.should == 'green'
    end

    it "should always return the winner if one exists" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      green = Split::Alternative.find('green', 'link_color')
      experiment.winner = 'green'

      experiment.next_alternative.name.should == 'green'
      green.increment_participation

      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      experiment.next_alternative.name.should == 'green'
    end
  end
end

