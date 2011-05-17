require 'spec_helper'
require 'multivariate/experiment'

describe Multivariate::Experiment do
  before(:each) { Multivariate.redis.flushall }

  it "should have a name" do
    experiment = Multivariate::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.name.should eql('basket_text')
  end
  
  it "should have alternatives" do
    experiment = Multivariate::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.alternatives.length.should be 2
  end
  
  it "should save to redis" do
    experiment = Multivariate::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.save
    Multivariate.redis.exists('basket_text').should be true
  end
  
  it "should return an existing experiment" do
    experiment = Multivariate::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.save
    Multivariate::Experiment.find('basket_text').name.should eql('basket_text')
  end

  describe 'winner' do
    it "should have no winner initially" do
      experiment = Multivariate::Experiment.find_or_create('link_color', 'blue', 'red')
      experiment.winner.should be_nil
    end

    it "should allow you to specify a winner" do
      experiment = Multivariate::Experiment.find_or_create('link_color', 'blue', 'red')
      experiment.winner = Multivariate::Alternative.find_or_create('red', 'link_color')
      experiment.save

      experiment = Multivariate::Experiment.find_or_create('link_color', 'blue', 'red')
      experiment.winner.name.should == 'red'
    end
  end

  describe 'next_alternative' do
    it "should return a random alternative from those with the least participants" do
      experiment = Multivariate::Experiment.find_or_create('link_color', 'blue', 'red', 'green')

      Multivariate::Alternative.find('blue', 'link_color').increment_participation
      Multivariate::Alternative.find('red', 'link_color').increment_participation

      experiment.next_alternative.name.should == 'green'
    end

    it "should always return the winner if one exists" do
      experiment = Multivariate::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      green = Multivariate::Alternative.find('green', 'link_color')
      experiment.winner = green
      experiment.save

      experiment.next_alternative.name.should == 'green'
      green.increment_participation

      experiment = Multivariate::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      experiment.next_alternative.name.should == 'green'
    end
  end
end

