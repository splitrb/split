require 'spec_helper'

describe Multivariate::Helper do
  before(:each) do
    REDIS.flushall
    Multivariate::Helper.current_user = {}
  end

  describe "ab_test" do
    it "should find or create an experiment from a name" do
      Multivariate::Helper.ab_test('link_color', 'blue', 'red').should eql('blue')
    end

    it "should assign a random alternative to a new user" do
      Multivariate::Helper.ab_test('link_color', 'blue', 'red')
      Multivariate::Helper.current_user['link_color'].should_not == nil
    end

    it "should increment the participation counter after assignment to a new user" do
      experiment = Multivariate::Experiment.find_or_create('link_color', 'blue', 'red')

      previous_red_count = Multivariate::Alternative.find('red', 'link_color').participant_count
      previous_blue_count = Multivariate::Alternative.find('blue', 'link_color').participant_count

      Multivariate::Helper.ab_test('link_color', 'blue', 'red')

      new_red_count = Multivariate::Alternative.find('red', 'link_color').participant_count
      new_blue_count = Multivariate::Alternative.find('blue', 'link_color').participant_count

      (new_red_count + new_blue_count).should eql(previous_red_count + previous_blue_count + 1)
    end

    it "should return the given alternative for an existing user" do
      experiment = Multivariate::Experiment.find_or_create('link_color', 'blue', 'red')
      alternative = Multivariate::Helper.ab_test('link_color', 'blue', 'red')
      repeat_alternative = Multivariate::Helper.ab_test('link_color', 'blue', 'red')
      alternative.should eql repeat_alternative
    end
  end
end