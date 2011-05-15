require 'spec_helper'

describe Multivariate::Helper do
  before(:each) do
    Multivariate.redis.flushall
    Multivariate::Helper.current_user = {}
  end

  describe "ab_test" do
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

  describe 'finished' do
    it 'should increment the counter for the completed alternative' do
      experiment = Multivariate::Experiment.find_or_create('link_color', 'blue', 'red')
      alternative_name = Multivariate::Helper.ab_test('link_color', 'blue', 'red')

      previous_completion_count = Multivariate::Alternative.find(alternative_name, 'link_color').completed_count

      Multivariate::Helper.finished('link_color')

      new_completion_count = Multivariate::Alternative.find(alternative_name, 'link_color').completed_count

      new_completion_count.should eql(previous_completion_count + 1)
    end
  end
  
  describe 'conversions' do
    it 'should return a conversion rate for an alternative' do
      experiment = Multivariate::Experiment.find_or_create('link_color', 'blue', 'red')
      alternative_name = Multivariate::Helper.ab_test('link_color', 'blue', 'red')
      
      previous_convertion_rate = Multivariate::Alternative.find(alternative_name, 'link_color').conversion_rate
      previous_convertion_rate.should eql(0.0)

      Multivariate::Helper.finished('link_color')
      
      new_convertion_rate = Multivariate::Alternative.find(alternative_name, 'link_color').conversion_rate
      new_convertion_rate.should eql(100.0)
    end
  end
end