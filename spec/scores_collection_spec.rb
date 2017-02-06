require 'spec_helper'
require 'split/scores_collection'
require 'time'

describe Split::ScoresCollection do
  let(:experiment_name) { 'experiment_name' }

  describe 'initialization' do
    let(:scores_collection) do
      Split::ScoresCollection.new('experiment_name', %w(score1 score2))
    end

    it 'should have an experiment_name' do
      expect(scores_collection.instance_variable_get(:@experiment_name))
        .to eq('experiment_name')
    end

    it 'should have a list of scores' do
      expect(scores_collection.instance_variable_get(:@scores))
        .to eq(%w(score1 score2))
    end
  end

  describe '#validate!' do
    it "shouldn't raise ArgumentError if @scores is nil?" do
      scores_collection = Split::ScoresCollection.new('experiment_name')
      expect { scores_collection.validate! }.not_to raise_error
    end

    it 'should raise ArgumentError if @scores is not an Array of Strings' do
      scores_collection1 = Split::ScoresCollection.new('experiment_name', 'not an array')
      scores_collection2 = Split::ScoresCollection.new('experiment_name', [:score1, :score2])
      expect { scores_collection1.validate! }.to raise_error(ArgumentError)
      expect { scores_collection2.validate! }.to raise_error(ArgumentError)
    end

    it "shouldn't raise ArgumentError if @scores is an Array of Strings" do
      scores_collection = Split::ScoresCollection.new('experiment_name', ['an array', 'of strings'])
      expect { scores_collection.validate! }.not_to raise_error
    end
  end
end
