# frozen_string_literal: true
require 'spec_helper'
require 'split/experiment'
require 'split/algorithms'
require 'time'

describe Split::Experiment do

  before(:example) do
    Split.configuration.experiments = {
      link_color: {
        alternatives: %w(blue red green)
      },
      basket_text: {
        alternatives: %w(Basket Cart)
      }
    }
  end

  def new_experiment(goals = [], scores = [])
    Split::Experiment.new('link_color', alternatives: %w(blue red green), goals: goals, scores: scores)
  end

  def alternative(color)
    Split::Alternative.new(color, 'link_color')
  end

  let(:experiment) { new_experiment }

  let(:blue) { alternative('blue') }
  let(:green) { alternative('green') }

  context 'with an experiment' do
    let(:experiment) { Split::Experiment.new('basket_text') }

    it 'should have a name' do
      expect(experiment.name).to eq('basket_text')
    end

    it 'should have alternatives' do
      expect(experiment.alternatives.length).to be 2
    end

    it 'should have alternatives with correct names' do
      expect(experiment.alternatives.collect(&:name)).to eq(%w(Basket Cart))
    end

    it 'should be resettable by default' do
      expect(experiment.resettable).to be_truthy
    end

    it 'should have empty (Array) scores by default' do
      expect(experiment.scores).to be_empty
    end

    it 'should save to redis' do
      experiment.save
      expect(Split.redis.sismember(:experiments, 'basket_text')).to be true
    end

    it 'should save the start time to redis' do
      experiment_start_time = Time.at(1_372_167_761)
      expect(Time).to receive(:now).and_return(experiment_start_time)
      experiment.save

      expect(Split::ExperimentCatalog.find('basket_text').start_time).to eq(experiment_start_time)
    end

    it 'should not save the start time to redis when start_manually is enabled' do
      expect(Split.configuration).to receive(:start_manually).and_return(true)
      experiment.save

      expect(Split::ExperimentCatalog.find('basket_text').start_time).to be_nil
    end

    it 'should handle having a start time stored as a string' do
      experiment_start_time = Time.parse('Sat Mar 03 14:01:03')
      expect(Time).to receive(:now).twice.and_return(experiment_start_time)
      experiment.save
      Split.redis.hset(:experiment_start_times, experiment.name, experiment_start_time)

      expect(Split::ExperimentCatalog.find('basket_text').start_time).to eq(experiment_start_time)
    end

    it 'should handle not having a start time' do
      experiment_start_time = Time.parse('Sat Mar 03 14:01:03')
      expect(Time).to receive(:now).and_return(experiment_start_time)
      experiment.save

      Split.redis.hdel(:experiment_start_times, experiment.name)

      expect(Split::ExperimentCatalog.find('basket_text').start_time).to be_nil
    end

    it 'should not create duplicates when saving multiple times' do
      experiment.save
      experiment.save
      expect(Split.redis.sismember(:experiments, 'basket_text')).to be true
    end

    describe 'new record?' do
      it "should know if it hasn't been saved yet" do
        expect(experiment.new_record?).to be_truthy
      end

      it 'should know if it has been saved yet' do
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
    it 'should set the algorithm when passed as an option to the initializer' do
      experiment = Split::Experiment.new('basket_text', alternatives: %w(Basket Cart), algorithm: Split::Algorithms::Whiplash)
      expect(experiment.algorithm).to eq(Split::Algorithms::Whiplash)
    end

    it 'should be possible to make an experiment not resettable' do
      experiment = Split::Experiment.new('basket_text', alternatives: %w(Basket Cart), resettable: false)
      expect(experiment.resettable).to be_falsey
    end
  end

  describe 'deleting' do
    it 'should delete itself' do
      experiment = Split::Experiment.new('basket_text', alternatives: %w(Basket Cart))
      experiment.save

      experiment.delete
      expect(Split.redis.exists('link_color')).to be false
      expect(Split::ExperimentCatalog.find('link_color')).to be_nil
    end

    it 'should increment the version' do
      expect(experiment.version).to eq(0)
      experiment.delete
      expect(experiment.version).to eq(1)
    end

    it 'should call the on_experiment_delete hook' do
      expect(Split.configuration.on_experiment_delete).to receive(:call)
      experiment.delete
    end

    it 'should call the on_before_experiment_delete hook' do
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
    it 'should have no winner initially' do
      expect(experiment.winner).to be_nil
    end

    it 'should allow you to specify a winner' do
      experiment.save
      experiment.winner = 'red'
      expect(experiment.winner.name).to eq('red')
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

    it 'should increment the version' do
      expect(experiment.version).to eq(0)
      experiment.reset
      expect(experiment.version).to eq(1)
    end

    it 'should call the on_experiment_reset hook' do
      expect(Split.configuration.on_experiment_reset).to receive(:call)
      experiment.reset
    end

    it 'should call the on_before_experiment_reset hook' do
      expect(Split.configuration.on_before_experiment_reset).to receive(:call)
      experiment.reset
    end
  end

  describe 'algorithm' do
    before(:example) do
      Split.configuration.experiments = {
        link_color: {
          alternatives: %w(blue red green)
        }
      }
    end

    let(:experiment) { Split::ExperimentCatalog.find_or_create('link_color') }

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
      before(:example) do
        Split.configuration.experiments = {
          link_color: {
            alternatives: %w(blue red green)
          }
        }
      end

      let(:experiment) { Split::ExperimentCatalog.find_or_create('link_color') }

      context 'with winner' do
        it 'should always return the winner' do
          green = Split::Alternative.new('green', 'link_color')
          experiment.winner = 'green'

          expect(experiment.next_alternative.name).to eq('green')
          green.increment_participation

          expect(experiment.next_alternative.name).to eq('green')
        end
      end

      context 'without winner' do
        it 'should use the specified algorithm' do
          experiment.algorithm = Split::Algorithms::Whiplash
          expect(experiment.algorithm).to receive(:choose_alternative).and_return(Split::Alternative.new('green', 'link_color'))
          expect(experiment.next_alternative.name).to eq('green')
        end
      end
    end
  end

  describe 'beta probability calculation' do
    before(:example) do
      Split.configuration.experiments = {
        mathematicians: {
          alternatives: %w(bernoulli poisson lagrange)
        },
        scientists: {
          alternatives: %w(einstein bohr)
        },
        link_color3: {
          alternatives: %w(blue red green),
          goals: %w(purchase refund)
        }
      }
    end

    it 'should return a hash with the probability of each alternative being the best' do
      experiment = Split::ExperimentCatalog.find_or_create('mathematicians')
      experiment.calc_winning_alternatives
      expect(experiment.alternative_probabilities).not_to be_nil
    end

    it 'should return between 46% and 54% probability for an experiment with 2 alternatives and no data' do
      experiment = Split::ExperimentCatalog.find_or_create('scientists')
      experiment.calc_winning_alternatives
      expect(experiment.alternatives[0].p_winner).to be_within(0.04).of(0.50)
    end

    it 'should calculate the probability of being the winning alternative separately for each goal' do
      experiment = Split::ExperimentCatalog.find_or_create('link_color3')
      goal1 = experiment.goals[0]
      goal2 = experiment.goals[1]
      experiment.alternatives.each do |alternative|
        alternative.participant_count = 50
        alternative.set_completed_count(10, goal1)
        alternative.set_completed_count(15 + rand(30), goal2)
      end
      experiment.calc_winning_alternatives
      alt = experiment.alternatives[0]
      p_goal1 = alt.p_winner(goal1)
      p_goal2 = alt.p_winner(goal2)
      expect(p_goal1).not_to be_within(0.04).of(p_goal2)
    end
  end
end
