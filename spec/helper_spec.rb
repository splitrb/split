require 'spec_helper'

describe Split::Helper do
  include Split::Helper

  before(:each) do
    Split.redis.flushall
    @session = {}
    params = nil
  end

  describe "ab_test" do
    it "should assign a random alternative to a new user when there are an equal number of alternatives assigned" do
      ab_test('link_color', 'blue', 'red')
      ['red', 'blue'].should include(ab_user['link_color'])
    end

    it "should increment the participation counter after assignment to a new user" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')

      previous_red_count = Split::Alternative.find('red', 'link_color').participant_count
      previous_blue_count = Split::Alternative.find('blue', 'link_color').participant_count

      ab_test('link_color', 'blue', 'red')

      new_red_count = Split::Alternative.find('red', 'link_color').participant_count
      new_blue_count = Split::Alternative.find('blue', 'link_color').participant_count

      (new_red_count + new_blue_count).should eql(previous_red_count + previous_blue_count + 1)
    end

    it "should return the given alternative for an existing user" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
      alternative = ab_test('link_color', 'blue', 'red')
      repeat_alternative = ab_test('link_color', 'blue', 'red')
      alternative.should eql repeat_alternative
    end

    it 'should always return the winner if one is present' do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
      experiment.winner = "orange"

      ab_test('link_color', 'blue', 'red').should == 'orange'
    end

    it "should allow the alternative to be force by passing it in the params" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
      @params = {'link_color' => 'blue'}
      alternative = ab_test('link_color', 'blue', 'red')
      alternative.should eql('blue')
    end
  end

  describe 'finished' do
    it 'should increment the counter for the completed alternative' do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
      alternative_name = ab_test('link_color', 'blue', 'red')

      previous_completion_count = Split::Alternative.find(alternative_name, 'link_color').completed_count

      finished('link_color')

      new_completion_count = Split::Alternative.find(alternative_name, 'link_color').completed_count

      new_completion_count.should eql(previous_completion_count + 1)
    end

    it "should clear out the user's participation from their session" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
      alternative_name = ab_test('link_color', 'blue', 'red')

      previous_completion_count = Split::Alternative.find(alternative_name, 'link_color').completed_count

      session[:split].should eql("link_color" => alternative_name)
      finished('link_color')
      session[:split].should == {}
    end
  end
  
  describe 'conversions' do
    it 'should return a conversion rate for an alternative' do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
      alternative_name = ab_test('link_color', 'blue', 'red')
      
      previous_convertion_rate = Split::Alternative.find(alternative_name, 'link_color').conversion_rate
      previous_convertion_rate.should eql(0.0)

      finished('link_color')
      
      new_convertion_rate = Split::Alternative.find(alternative_name, 'link_color').conversion_rate
      new_convertion_rate.should eql(1.0)
    end
  end

  describe 'when user is a robot' do
    before(:each) do
      @request = OpenStruct.new(:user_agent => 'Googlebot/2.1 (+http://www.google.com/bot.html)')
    end

    describe 'ab_test' do
      it 'should return the control' do
        experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
        alternative = ab_test('link_color', 'blue', 'red')
        alternative.should eql experiment.control.name
      end

      it "should not increment the participation count" do
        experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')

        previous_red_count = Split::Alternative.find('red', 'link_color').participant_count
        previous_blue_count = Split::Alternative.find('blue', 'link_color').participant_count

        ab_test('link_color', 'blue', 'red')

        new_red_count = Split::Alternative.find('red', 'link_color').participant_count
        new_blue_count = Split::Alternative.find('blue', 'link_color').participant_count

        (new_red_count + new_blue_count).should eql(previous_red_count + previous_blue_count)
      end
    end
    describe 'finished' do
      it "should not increment the completed count" do
        experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
        alternative_name = ab_test('link_color', 'blue', 'red')

        previous_completion_count = Split::Alternative.find(alternative_name, 'link_color').completed_count

        finished('link_color')

        new_completion_count = Split::Alternative.find(alternative_name, 'link_color').completed_count

        new_completion_count.should eql(previous_completion_count)
      end
    end
  end
  describe 'when ip address is ignored' do
    before(:each) do
      @request = OpenStruct.new(:ip => '81.19.48.130')
      Split.configure do |c|
        c.ignore_ip_addresses << '81.19.48.130'
      end
    end

    describe 'ab_test' do
      it 'should return the control' do
        experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
        alternative = ab_test('link_color', 'blue', 'red')
        alternative.should eql experiment.control.name
      end

      it "should not increment the participation count" do
        experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')

        previous_red_count = Split::Alternative.find('red', 'link_color').participant_count
        previous_blue_count = Split::Alternative.find('blue', 'link_color').participant_count

        ab_test('link_color', 'blue', 'red')

        new_red_count = Split::Alternative.find('red', 'link_color').participant_count
        new_blue_count = Split::Alternative.find('blue', 'link_color').participant_count

        (new_red_count + new_blue_count).should eql(previous_red_count + previous_blue_count)
      end
    end
    describe 'finished' do
      it "should not increment the completed count" do
        experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
        alternative_name = ab_test('link_color', 'blue', 'red')

        previous_completion_count = Split::Alternative.find(alternative_name, 'link_color').completed_count

        finished('link_color')

        new_completion_count = Split::Alternative.find(alternative_name, 'link_color').completed_count

        new_completion_count.should eql(previous_completion_count)
      end
    end
  end
end