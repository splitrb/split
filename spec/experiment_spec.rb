require 'spec_helper'
require 'multivariate/experiment'

describe Multivariate::Experiment do
  before(:each) { REDIS.flushall }

  it "should have a name" do
    experiment = Multivariate::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.name.should eql('basket_text')
  end
  
  it "should have an alternatives" do
    experiment = Multivariate::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.alternatives.should eql(['Basket', "Cart"])
  end
  
  it "should save to redis" do
    experiment = Multivariate::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.save
    REDIS.exists('basket_text').should be true
  end
  
  it "should return an existing experiment" do
    experiment = Multivariate::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.save
    Multivariate::Experiment.find('basket_text').name.should eql('basket_text')
  end
end

