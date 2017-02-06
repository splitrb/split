require 'spec_helper'
require 'split/goals_collection'
require 'time'

describe Split::GoalsCollection do
  let(:experiment_name) { 'experiment_name' }

  describe 'initialization' do
    let(:goals_collection) do
      Split::GoalsCollection.new('experiment_name', %w(goal1 goal2))
    end

    it 'should have an experiment_name' do
      expect(goals_collection.instance_variable_get(:@experiment_name))
        .to eq('experiment_name')
    end

    it 'should have a list of goals' do
      expect(goals_collection.instance_variable_get(:@goals))
        .to eq(%w(goal1 goal2))
    end
  end

  describe '#validate!' do
    it "should't raise ArgumentError if @goals is nil?" do
      goals_collection = Split::GoalsCollection.new('experiment_name')
      expect { goals_collection.validate! }.not_to raise_error
    end

    it 'should raise ArgumentError if @goals is not an Array' do
      goals_collection = Split::GoalsCollection
                         .new('experiment_name', 'not an array')
      expect { goals_collection.validate! }.to raise_error(ArgumentError)
    end

    it "should't raise ArgumentError if @goals is an array" do
      goals_collection = Split::GoalsCollection
                         .new('experiment_name', ['an array'])
      expect { goals_collection.validate! }.not_to raise_error
    end
  end
end
