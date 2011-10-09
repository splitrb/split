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

  it "should not create duplicates when saving multiple times" do
    experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.save
    experiment.save
    Split.redis.exists('basket_text').should be true
    Split.redis.lrange('basket_text', 0, -1).should eql(['Basket', "Cart"])
  end

  describe 'deleting' do
    it 'should delete itself' do
      experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
      experiment.save

      experiment.delete
      Split.redis.exists('basket_text').should be false
      lambda { Split::Experiment.find('link_color') }.should raise_error
    end

    it "should increment the version" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      experiment.version.should eql(0)
      experiment.delete
      experiment.version.should eql(1)
    end
  end

  describe 'new record?' do
    it "should know if it hasn't been saved yet" do
      experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
      experiment.new_record?.should be_true
    end

    it "should know if it has been saved yet" do
      experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
      experiment.save
      experiment.new_record?.should be_false
    end
  end

  it "should return an existing experiment" do
    experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
    experiment.save
    Split::Experiment.find('basket_text').name.should eql('basket_text')
  end

  describe 'control' do
    it 'should be the first alternative' do
      experiment = Split::Experiment.new('basket_text', 'Basket', "Cart")
      experiment.save
      experiment.control.name.should eql('Basket')
    end
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

  describe 'reset' do
    it 'should reset all alternatives' do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      green = Split::Alternative.find('green', 'link_color')
      experiment.winner = 'green'

      experiment.next_alternative.name.should eql('green')
      green.increment_participation

      experiment.reset

      reset_green = Split::Alternative.find('green', 'link_color')
      reset_green.participant_count.should eql(0)
      reset_green.completed_count.should eql(0)
    end

    it 'should reset the winner' do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      green = Split::Alternative.find('green', 'link_color')
      experiment.winner = 'green'

      experiment.next_alternative.name.should eql('green')
      green.increment_participation

      experiment.reset

      experiment.winner.should be_nil
    end

    it "should increment the version" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      experiment.version.should eql(0)
      experiment.reset
      experiment.version.should eql(1)
    end
  end

  describe 'next_alternative' do
    it "should return a random alternative from those with the least participants" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')

      Split::Alternative.find('blue', 'link_color').increment_participation
      Split::Alternative.find('red', 'link_color').increment_participation

      experiment.next_alternative.name.should eql('green')
    end

    it "should always return the winner if one exists" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      green = Split::Alternative.find('green', 'link_color')
      experiment.winner = 'green'

      experiment.next_alternative.name.should eql('green')
      green.increment_participation

      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      experiment.next_alternative.name.should eql('green')
    end
  end

  describe 'changing an existing experiment' do
    it "should reset an experiment if it is loaded with different alternatives" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      blue = Split::Alternative.find('blue', 'link_color')
      blue.participant_count = 5
      blue.save
      same_experiment = Split::Experiment.find_or_create('link_color', 'blue', 'yellow', 'orange')
      same_experiment.alternatives.map(&:name).should eql(['blue', 'yellow', 'orange'])
      new_blue = Split::Alternative.find('blue', 'link_color')
      new_blue.participant_count.should eql(0)
    end
  end

  describe 'alternatives passed as non-strings' do
    it "should throw an exception if an alternative is passed that is not a string" do
      lambda { Split::Experiment.find_or_create('link_color', :blue, :red) }.should raise_error
      lambda { Split::Experiment.find_or_create('link_enabled', true, false) }.should raise_error
    end
  end
end