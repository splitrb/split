require 'spec_helper'
require 'split/goals_collection'
require 'time'

describe Split::GoalsCollection do
  let(:experiment_name) { 'experiment_name' }

  describe 'initialization' do
    let(:goals_collection) {
      Split::GoalsCollection.new('experiment_name', ['goal1', 'goal2'])
    }

    it "should have an experiment_name" do
      expect(goals_collection.instance_variable_get(:@experiment_name)).
        to eq('experiment_name')
    end

    it "should have a list of goals" do
      expect(goals_collection.instance_variable_get(:@goals)).
        to eq(['goal1', 'goal2'])
    end
  end

  describe "#validate!" do
    it "should't raise ArgumentError if @goals is nil?" do
      goals_collection = Split::GoalsCollection.new('experiment_name')
      expect { goals_collection.validate! }.not_to raise_error
    end

    it "should raise ArgumentError if @goals is not an Array" do
      goals_collection = Split::GoalsCollection.
        new('experiment_name', 'not an array')
      expect { goals_collection.validate! }.to raise_error(ArgumentError)
    end

    it "should't raise ArgumentError if @goals is an array" do
      goals_collection = Split::GoalsCollection.
        new('experiment_name', ['an array'])
      expect { goals_collection.validate! }.not_to raise_error
    end
  end

  describe "#delete" do
    let(:goals_key) { "#{experiment_name}:goals" }

    it "should delete goals from redis" do
      goals_collection = Split::GoalsCollection.new(experiment_name, ['goal1'])
      goals_collection.save

      goals_collection.delete
      expect(Split.redis.exists(goals_key)).to be false
    end
  end

  describe "#save" do
    let(:goals_key) { "#{experiment_name}:goals" }

    it "should return false if @goals is nil" do
      goals_collection = Split::GoalsCollection.
        new(experiment_name, nil)

      expect(goals_collection.save).to be false
    end

    it "should save goals to redis if @goals is valid" do
      goals = ['valid goal 1', 'valid goal 2']
      collection = Split::GoalsCollection.new(experiment_name, goals)
      collection.save

      expect(Split.redis.lrange(goals_key, 0, -1)).to eq goals
    end

    it "should return @goals if @goals is valid" do
      goals_collection = Split::GoalsCollection.
        new(experiment_name, ['valid goal'])

      expect(goals_collection.save).to eq(['valid goal'])
    end
  end
end
