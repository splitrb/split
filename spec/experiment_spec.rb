require 'spec_helper'
require 'split/experiment'
require 'split/algorithms'
require 'time'

describe Split::Experiment do
  context "with an experiment" do
    let(:experiment) { Split::Experiment.new('basket_text', :alternative_names => ['Basket', "Cart"]) }
    
    it "should have a name" do
      experiment.name.should eql('basket_text')
    end

    it "should have alternatives" do
      experiment.alternatives.length.should be 2
    end
    
    it "should have alternatives with correct names" do
      experiment.alternatives.collect{|a| a.name}.should == ['Basket', 'Cart']
    end
    
    it "should be resettable by default" do
      experiment.resettable.should be_true
    end
    
    it "should save to redis" do
      experiment.save
      Split.redis.exists('basket_text').should be true
    end

    it "should save the start time to redis" do
      experiment_start_time = Time.parse("Sat Mar 03 14:01:03")
      Time.stub(:now => experiment_start_time)
      experiment.save

      Split::Experiment.find('basket_text').start_time.should == experiment_start_time
    end
  
    it "should save the selected algorithm to redis" do
      experiment_algorithm = Split::Algorithms::Whiplash
      experiment.algorithm = experiment_algorithm 
      experiment.save

      Split::Experiment.find('basket_text').algorithm.should == experiment_algorithm
    end

    it "should handle not having a start time" do
      experiment_start_time = Time.parse("Sat Mar 03 14:01:03")
      Time.stub(:now => experiment_start_time)
      experiment.save

      Split.redis.hdel(:experiment_start_times, experiment.name)

      Split::Experiment.find('basket_text').start_time.should == nil
    end

    it "should not create duplicates when saving multiple times" do
      experiment.save
      experiment.save
      Split.redis.exists('basket_text').should be true
      Split.redis.lrange('basket_text', 0, -1).should eql(['Basket', "Cart"])
    end
    
    describe 'new record?' do
      it "should know if it hasn't been saved yet" do
        experiment.new_record?.should be_true
      end

      it "should know if it has been saved yet" do
        experiment.save
        experiment.new_record?.should be_false
      end
    end
    
    describe 'find' do
      it "should return an existing experiment" do
        experiment.save
        Split::Experiment.find('basket_text').name.should eql('basket_text')
      end

      it "should return an existing experiment" do
        Split::Experiment.find('non_existent_experiment').should be_nil
      end
    end
    
    describe 'control' do
      it 'should be the first alternative' do
        experiment.save
        experiment.control.name.should eql('Basket')
      end
    end
  end
  describe 'initialization' do
    it "should set the algorithm when passed as an option to the initializer" do
       experiment = Split::Experiment.new('basket_text', :alternative_names => ['Basket', "Cart"], :algorithm =>  Split::Algorithms::Whiplash)
       experiment.algorithm.should == Split::Algorithms::Whiplash
    end
  
    it "should be possible to make an experiment not resettable" do
      experiment = Split::Experiment.new('basket_text', :alternative_names => ['Basket', "Cart"], :resettable => false)
      experiment.resettable.should be_false    
    end
  end
  
  describe 'persistent configuration' do
  
    it "should persist resettable in redis" do
      experiment = Split::Experiment.new('basket_text', :alternative_names => ['Basket', "Cart"], :resettable => false)
      experiment.save
        
      e = Split::Experiment.find('basket_text')
      e.should == experiment
      e.resettable.should be_false
    
    end
    
    it "should persist algorithm in redis" do
      experiment = Split::Experiment.new('basket_text', :alternative_names => ['Basket', "Cart"], :algorithm => Split::Algorithms::Whiplash)
      experiment.save
  
      e = Split::Experiment.find('basket_text')
      e.should == experiment
      e.algorithm.should == Split::Algorithms::Whiplash
    end
  end

  
  
  
  describe 'deleting' do
    it 'should delete itself' do
      experiment = Split::Experiment.new('basket_text', :alternative_names => [ 'Basket', "Cart"])
      experiment.save

      experiment.delete
      Split.redis.exists('basket_text').should be false
      Split::Experiment.find('basket_text').should be_nil
    end

    it "should increment the version" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      experiment.version.should eql(0)
      experiment.delete
      experiment.version.should eql(1)
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
      green = Split::Alternative.new('green', 'link_color')
      experiment.winner = 'green'

      experiment.next_alternative.name.should eql('green')
      green.increment_participation

      experiment.reset

      reset_green = Split::Alternative.new('green', 'link_color')
      reset_green.participant_count.should eql(0)
      reset_green.completed_count.should eql(0)
    end

    it 'should reset the winner' do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      green = Split::Alternative.new('green', 'link_color')
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
  
  describe 'algorithm' do
    let(:experiment) { Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green') }
    
    it 'should use the default algorithm if none is specified' do
      experiment.algorithm.should == Split.configuration.algorithm
    end
    
    it 'should use the user specified algorithm for this experiment if specified' do
      experiment.algorithm = Split::Algorithms::Whiplash
      experiment.algorithm.should == Split::Algorithms::Whiplash
    end
  end
  
  describe 'next_alternative' do
    let(:experiment) { Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green') }
    
    it "should always return the winner if one exists" do
      green = Split::Alternative.new('green', 'link_color')
      experiment.winner = 'green'

      experiment.next_alternative.name.should eql('green')
      green.increment_participation

      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      experiment.next_alternative.name.should eql('green')
    end
    
    it "should use the specified algorithm if a winner does not exist" do
      Split.configuration.algorithm.should_receive(:choose_alternative).and_return(Split::Alternative.new('green', 'link_color'))
      experiment.next_alternative.name.should eql('green')
    end
  end
  
  describe 'single alternative' do
    let(:experiment) { Split::Experiment.find_or_create('link_color', 'blue') }
    
    it "should always return the color blue" do
      experiment.next_alternative.name.should eql('blue')
    end 
  end

  describe 'changing an existing experiment' do
    it "should reset an experiment if it is loaded with different alternatives" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      blue = Split::Alternative.new('blue', 'link_color')
      blue.participant_count = 5
      blue.save
      same_experiment = Split::Experiment.find_or_create('link_color', 'blue', 'yellow', 'orange')
      same_experiment.alternatives.map(&:name).should eql(['blue', 'yellow', 'orange'])
      new_blue = Split::Alternative.new('blue', 'link_color')
      new_blue.participant_count.should eql(0)
    end

    it "should only reset once" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red', 'green')
      experiment.version.should eql(0)
      same_experiment = Split::Experiment.find_or_create('link_color', 'blue', 'yellow', 'orange')
      same_experiment.version.should eql(1)
      same_experiment_again = Split::Experiment.find_or_create('link_color', 'blue', 'yellow', 'orange')
      same_experiment_again.version.should eql(1)
    end
  end

  describe 'alternatives passed as non-strings' do
    it "should throw an exception if an alternative is passed that is not a string" do
      lambda { Split::Experiment.find_or_create('link_color', :blue, :red) }.should raise_error
      lambda { Split::Experiment.find_or_create('link_enabled', true, false) }.should raise_error
    end
  end

  describe 'specifying weights' do
    it "should work for a new experiment" do
      experiment = Split::Experiment.find_or_create('link_color', {'blue' => 1}, {'red' => 2 })

      experiment.alternatives.map(&:weight).should == [1, 2]
    end

    it "should work for an existing experiment" do
      experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
      experiment.save

      same_experiment = Split::Experiment.find_or_create('link_color', {'blue' => 1}, {'red' => 2 })
      same_experiment.alternatives.map(&:weight).should == [1, 2]
    end
  end
end
