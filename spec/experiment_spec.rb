# frozen_string_literal: true
require 'spec_helper'
require 'time'

describe Split::Experiment do
  def new_experiment(goals=[])
    Split::Experiment.new('link_color', :alternatives => ['blue', 'red', 'green'], :goals => goals)
  end

  def alternative(color)
    Split::Alternative.new(color, 'link_color')
  end

  let(:experiment) { new_experiment }

  let(:blue) { alternative("blue") }
  let(:green) { alternative("green") }

  context "with an experiment" do
    let(:experiment) { Split::Experiment.new('basket_text', :alternatives => ['Basket', "Cart"]) }

    it "should have a name" do
      expect(experiment.name).to eq('basket_text')
    end

    it "should have alternatives" do
      expect(experiment.alternatives.length).to be 2
    end

    it "should have alternatives with correct names" do
      expect(experiment.alternatives.collect{|a| a.name}).to eq(['Basket', 'Cart'])
    end

    it "should be resettable by default" do
      expect(experiment.resettable).to be_truthy
    end

    it "should save to redis" do
      experiment.save
      expect(Split.redis.exists('basket_text')).to be true
    end

    it "should save the start time to redis" do
      experiment_start_time = Time.at(1372167761)
      expect(Time).to receive(:now).and_return(experiment_start_time)
      experiment.save

      expect(Split::ExperimentCatalog.find('basket_text').start_time).to eq(experiment_start_time)
    end

    it "should not save the start time to redis when start_manually is enabled" do
      expect(Split.configuration).to receive(:start_manually).and_return(true)
      experiment.save

      expect(Split::ExperimentCatalog.find('basket_text').start_time).to be_nil
    end

    it "should save the selected algorithm to redis" do
      experiment_algorithm = Split::Algorithms::Whiplash
      experiment.algorithm = experiment_algorithm
      experiment.save

      expect(Split::ExperimentCatalog.find('basket_text').algorithm).to eq(experiment_algorithm)
    end

    it "should handle having a start time stored as a string" do
      experiment_start_time = Time.parse("Sat Mar 03 14:01:03")
      expect(Time).to receive(:now).twice.and_return(experiment_start_time)
      experiment.save
      Split.redis.hset(:experiment_start_times, experiment.name, experiment_start_time)

      expect(Split::ExperimentCatalog.find('basket_text').start_time).to eq(experiment_start_time)
    end

    it "should handle not having a start time" do
      experiment_start_time = Time.parse("Sat Mar 03 14:01:03")
      expect(Time).to receive(:now).and_return(experiment_start_time)
      experiment.save

      Split.redis.hdel(:experiment_start_times, experiment.name)

      expect(Split::ExperimentCatalog.find('basket_text').start_time).to be_nil
    end

    it "should not create duplicates when saving multiple times" do
      experiment.save
      experiment.save
      expect(Split.redis.exists('basket_text')).to be true
      expect(Split.redis.lrange('basket_text', 0, -1)).to eq(['{"Basket":1}', '{"Cart":1}'])
    end

    describe 'new record?' do
      it "should know if it hasn't been saved yet" do
        expect(experiment.new_record?).to be_truthy
      end

      it "should know if it has been saved yet" do
        experiment.save
        expect(experiment.new_record?).to be_falsey
      end
    end

    describe 'control' do
      it 'should be the first alternative' do
        experiment.save
        expect(experiment.control.name).to eq('Basket')
      end
    end
  end

  describe 'initialization' do
    it "should set the algorithm when passed as an option to the initializer" do
       experiment = Split::Experiment.new('basket_text', :alternatives => ['Basket', "Cart"], :algorithm =>  Split::Algorithms::Whiplash)
       expect(experiment.algorithm).to eq(Split::Algorithms::Whiplash)
    end

    it "should be possible to make an experiment not resettable" do
      experiment = Split::Experiment.new('basket_text', :alternatives => ['Basket', "Cart"], :resettable => false)
      expect(experiment.resettable).to be_falsey
    end
  end

  describe 'persistent configuration' do

    it "should persist resettable in redis" do
      experiment = Split::Experiment.new('basket_text', :alternatives => ['Basket', "Cart"], :resettable => false)
      experiment.save

      e = Split::ExperimentCatalog.find('basket_text')
      expect(e).to eq(experiment)
      expect(e.resettable).to be_falsey

    end

    describe '#metadata' do
      let(:experiment) { Split::Experiment.new('basket_text', :alternatives => ['Basket', "Cart"], :algorithm => Split::Algorithms::Whiplash, :metadata => meta) }
      context 'simple hash' do
        let(:meta) {  { 'basket' => 'a', 'cart' => 'b' } }
        it "should persist metadata in redis" do
          experiment.save
          e = Split::ExperimentCatalog.find('basket_text')
          expect(e).to eq(experiment)
          expect(e.metadata).to eq(meta)
        end
      end

      context 'nested hash' do
        let(:meta) {  { 'basket' => { 'one' => 'two' }, 'cart' => 'b' } }
        it "should persist metadata in redis" do
          experiment.save
          e = Split::ExperimentCatalog.find('basket_text')
          expect(e).to eq(experiment)
          expect(e.metadata).to eq(meta)
        end
      end
    end

    it "should persist algorithm in redis" do
      experiment = Split::Experiment.new('basket_text', :alternatives => ['Basket', "Cart"], :algorithm => Split::Algorithms::Whiplash)
      experiment.save

      e = Split::ExperimentCatalog.find('basket_text')
      expect(e).to eq(experiment)
      expect(e.algorithm).to eq(Split::Algorithms::Whiplash)
    end

    it "should persist a new experiment in redis, that does not exist in the configuration file" do
      experiment = Split::Experiment.new('foobar', :alternatives => ['tra', 'la'], :algorithm => Split::Algorithms::Whiplash)
      experiment.save

      e = Split::ExperimentCatalog.find('foobar')
      expect(e).to eq(experiment)
      expect(e.alternatives.collect{|a| a.name}).to eq(['tra', 'la'])
    end
  end

  describe 'deleting' do
    it 'should delete itself' do
      experiment = Split::Experiment.new('basket_text', :alternatives => [ 'Basket', "Cart"])
      experiment.save

      experiment.delete
      expect(Split.redis.exists('link_color')).to be false
      expect(Split::ExperimentCatalog.find('link_color')).to be_nil
    end

    it "should increment the version" do
      expect(experiment.version).to eq(0)
      experiment.delete
      expect(experiment.version).to eq(1)
    end

    it "should call the on_experiment_delete hook" do
      expect(Split.configuration.on_experiment_delete).to receive(:call)
      experiment.delete
    end

    it "should call the on_before_experiment_delete hook" do
      expect(Split.configuration.on_before_experiment_delete).to receive(:call)
      experiment.delete
    end

    it 'should reset the start time if the experiment should be manually started' do
      Split.configuration.start_manually = true
      experiment.start
      experiment.delete
      expect(experiment.start_time).to be_nil
    end
  end


  describe 'winner' do
    it "should have no winner initially" do
      expect(experiment.winner).to be_nil
    end
  end

  describe 'winner=' do
    it "should allow you to specify a winner" do
      experiment.save
      experiment.winner = 'red'
      expect(experiment.winner.name).to eq('red')
    end

    context 'when has_winner state is memoized' do
      before { expect(experiment).to_not have_winner }

      it 'should keep has_winner state consistent' do
        experiment.winner = 'red'
        expect(experiment).to have_winner
      end
    end
  end

  describe 'reset_winner' do
    before { experiment.winner = 'green' }

    it 'should reset the winner' do
      experiment.reset_winner
      expect(experiment.winner).to be_nil
    end

    context 'when has_winner state is memoized' do
      before { expect(experiment).to have_winner }

      it 'should keep has_winner state consistent' do
        experiment.reset_winner
        expect(experiment).to_not have_winner
      end
    end
  end

  describe 'has_winner?' do
    context 'with winner' do
      before { experiment.winner = 'red' }

      it 'returns true' do
        expect(experiment).to have_winner
      end
    end

    context 'without winner' do
      it 'returns false' do
        expect(experiment).to_not have_winner
      end
    end

    it 'memoizes has_winner state' do
      expect(experiment).to receive(:winner).once
      expect(experiment).to_not have_winner
      expect(experiment).to_not have_winner
    end
  end

  describe 'reset' do
    let(:reset_manually) { false }

    before do
      allow(Split.configuration).to receive(:reset_manually).and_return(reset_manually)
      experiment.save
      green.increment_participation
      green.increment_participation
    end

    it 'should reset all alternatives' do
      experiment.winner = 'green'

      expect(experiment.next_alternative.name).to eq('green')
      green.increment_participation

      experiment.reset

      expect(green.participant_count).to eq(0)
      expect(green.completed_count).to eq(0)
    end

    it 'should reset the winner' do
      experiment.winner = 'green'

      expect(experiment.next_alternative.name).to eq('green')
      green.increment_participation

      experiment.reset

      expect(experiment.winner).to be_nil
    end

    it "should increment the version" do
      expect(experiment.version).to eq(0)
      experiment.reset
      expect(experiment.version).to eq(1)
    end

    it "should call the on_experiment_reset hook" do
      expect(Split.configuration.on_experiment_reset).to receive(:call)
      experiment.reset
    end

    it "should call the on_before_experiment_reset hook" do
      expect(Split.configuration.on_before_experiment_reset).to receive(:call)
      experiment.reset
    end
  end

  describe 'algorithm' do
    let(:experiment) { Split::ExperimentCatalog.find_or_create('link_color', 'blue', 'red', 'green') }

    it 'should use the default algorithm if none is specified' do
      expect(experiment.algorithm).to eq(Split.configuration.algorithm)
    end

    it 'should use the user specified algorithm for this experiment if specified' do
      experiment.algorithm = Split::Algorithms::Whiplash
      expect(experiment.algorithm).to eq(Split::Algorithms::Whiplash)
    end
  end

  describe '#next_alternative' do
    context 'with multiple alternatives' do
      let(:experiment) { Split::ExperimentCatalog.find_or_create('link_color', 'blue', 'red', 'green') }

      context 'with winner' do
        it "should always return the winner" do
          green = Split::Alternative.new('green', 'link_color')
          experiment.winner = 'green'

          expect(experiment.next_alternative.name).to eq('green')
          green.increment_participation

          expect(experiment.next_alternative.name).to eq('green')
        end
      end

      context 'without winner' do
        it "should use the specified algorithm" do
          experiment.algorithm = Split::Algorithms::Whiplash
          expect(experiment.algorithm).to receive(:choose_alternative).and_return(Split::Alternative.new('green', 'link_color'))
          expect(experiment.next_alternative.name).to eq('green')
        end
      end
    end

    context 'with single alternative' do
      let(:experiment) { Split::ExperimentCatalog.find_or_create('link_color', 'blue') }

      it "should always return the only alternative" do
        expect(experiment.next_alternative.name).to eq('blue')
        expect(experiment.next_alternative.name).to eq('blue')
      end
    end
  end

  describe 'changing an existing experiment' do
    def same_but_different_alternative
      Split::ExperimentCatalog.find_or_create('link_color', 'blue', 'yellow', 'orange')
    end

    it "should reset an experiment if it is loaded with different alternatives" do
      experiment.save
      blue.participant_count = 5
      same_experiment = same_but_different_alternative
      expect(same_experiment.alternatives.map(&:name)).to eq(['blue', 'yellow', 'orange'])
      expect(blue.participant_count).to eq(0)
    end

    it "should only reset once" do
      experiment.save
      expect(experiment.version).to eq(0)
      same_experiment = same_but_different_alternative
      expect(same_experiment.version).to eq(1)
      same_experiment_again = same_but_different_alternative
      expect(same_experiment_again.version).to eq(1)
    end

    context 'when experiment configuration is changed' do
      let(:reset_manually) { false }

      before do
        experiment.save
        allow(Split.configuration).to receive(:reset_manually).and_return(reset_manually)
        green.increment_participation
        green.increment_participation
        experiment.set_alternatives_and_options(alternatives: %w(blue red green zip),
                                                goals: %w(purchase))
        experiment.save
      end

      it 'resets all alternatives' do
        expect(green.participant_count).to eq(0)
        expect(green.completed_count).to eq(0)
      end

      context 'when reset_manually is set' do
        let(:reset_manually) { true }

        it 'does not reset alternatives' do
          expect(green.participant_count).to eq(2)
          expect(green.completed_count).to eq(0)
        end
      end
    end
  end

  describe 'alternatives passed as non-strings' do
    it "should throw an exception if an alternative is passed that is not a string" do
      expect(lambda { Split::ExperimentCatalog.find_or_create('link_color', :blue, :red) }).to raise_error(ArgumentError)
      expect(lambda { Split::ExperimentCatalog.find_or_create('link_enabled', true, false) }).to raise_error(ArgumentError)
    end
  end

  describe 'specifying weights' do
    let(:experiment_with_weight) {
      Split::ExperimentCatalog.find_or_create('link_color', {'blue' => 1}, {'red' => 2 })
    }

    it "should work for a new experiment" do
      expect(experiment_with_weight.alternatives.map(&:weight)).to eq([1, 2])
    end

    it "should work for an existing experiment" do
      experiment.save
      expect(experiment_with_weight.alternatives.map(&:weight)).to eq([1, 2])
    end
  end

  describe "specifying goals" do
    let(:experiment) {
      new_experiment(["purchase"])
    }

    context "saving experiment" do
      let(:same_but_different_goals) { Split::ExperimentCatalog.find_or_create({'link_color' => ["purchase", "refund"]}, 'blue', 'red', 'green') }

      before { experiment.save }

      it "can find existing experiment" do
        expect(Split::ExperimentCatalog.find("link_color").name).to eq("link_color")
      end

      it "should reset an experiment if it is loaded with different goals" do
        same_but_different_goals
        expect(Split::ExperimentCatalog.find("link_color").goals).to eq(["purchase", "refund"])
      end

    end

    it "should have goals" do
      expect(experiment.goals).to eq(["purchase"])
    end

    context "find or create experiment" do
      it "should have correct goals"  do
        experiment = Split::ExperimentCatalog.find_or_create({'link_color3' => ["purchase", "refund"]}, 'blue', 'red', 'green')
        expect(experiment.goals).to eq(["purchase", "refund"])
        experiment = Split::ExperimentCatalog.find_or_create('link_color3', 'blue', 'red', 'green')
        expect(experiment.goals).to eq([])
      end
    end
  end

  describe "beta probability calculation" do
    it "should return a hash with the probability of each alternative being the best" do
      experiment = Split::ExperimentCatalog.find_or_create('mathematicians', 'bernoulli', 'poisson', 'lagrange')
      experiment.calc_winning_alternatives
      expect(experiment.alternative_probabilities).not_to be_nil
    end

    it "should return between 46% and 54% probability for an experiment with 2 alternatives and no data" do
      experiment = Split::ExperimentCatalog.find_or_create('scientists', 'einstein', 'bohr')
      experiment.calc_winning_alternatives
      expect(experiment.alternatives[0].p_winner).to be_within(0.04).of(0.50)
    end

    it "should calculate the probability of being the winning alternative separately for each goal", :skip => true do
      experiment = Split::ExperimentCatalog.find_or_create({'link_color3' => ["purchase", "refund"]}, 'blue', 'red', 'green')
      goal1 = experiment.goals[0]
      goal2 = experiment.goals[1]
      experiment.alternatives.each do |alternative|
        alternative.participant_count = 50
        alternative.set_completed_count(10, goal1)
        alternative.set_completed_count(15+rand(30), goal2)
      end
      experiment.calc_winning_alternatives
      alt = experiment.alternatives[0]
      p_goal1 = alt.p_winner(goal1)
      p_goal2 = alt.p_winner(goal2)
      expect(p_goal1).not_to be_within(0.04).of(p_goal2)
    end

    it "should return nil and not re-calculate probabilities if they have already been calculated today" do
      experiment = Split::ExperimentCatalog.find_or_create({'link_color3' => ["purchase", "refund"]}, 'blue', 'red', 'green')
      expect(experiment.calc_winning_alternatives).not_to be nil
      expect(experiment.calc_winning_alternatives).to be nil
    end
  end
end
