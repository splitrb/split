require 'spec_helper'
require 'split/scores_collection'
require 'time'

describe Split::ScoresCollection do
  let(:experiment_name) { 'experiment_name' }

  describe 'initialization' do
    let(:scores_collection) {
      Split::ScoresCollection.new('experiment_name', ['score1', 'score2'])
    }

    it "should have an experiment_name" do
      expect(scores_collection.instance_variable_get(:@experiment_name)).
        to eq('experiment_name')
    end

    it "should have a list of scores" do
      expect(scores_collection.instance_variable_get(:@scores)).
        to eq(['score1', 'score2'])
    end
  end

  describe "#validate!" do
    it "shouldn't raise ArgumentError if @scores is nil?" do
      scores_collection = Split::ScoresCollection.new('experiment_name')
      expect { scores_collection.validate! }.not_to raise_error
    end

    it "should raise ArgumentError if @scores is not an Array of Strings" do
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

  describe "#delete" do
    let(:scores_key) { "#{experiment_name}:scores" }

    it "should delete scores from redis" do
      scores_collection = Split::ScoresCollection.new(experiment_name, ['score1'])
      scores_collection.save

      scores_collection.delete
      expect(Split.redis.exists(scores_key)).to be false
    end
  end

  describe "#save" do
    let(:scores_key) { "#{experiment_name}:scores" }

    it "should return false if @scores is nil" do
      scores_collection = Split::ScoresCollection.new(experiment_name, nil)
      expect(scores_collection.save).to be false
    end

    it "should save scores to redis if @scores is valid" do
      scores = ['valid score 1', 'valid score 2']
      collection = Split::ScoresCollection.new(experiment_name, scores)
      collection.save
      expect(Split.redis.lrange(scores_key, 0, -1)).to eq scores
    end

    it "should return @scores if @scores is valid" do
      scores_collection = Split::ScoresCollection.new(experiment_name, ['valid score'])
      expect(scores_collection.save).to eq(['valid score'])
    end
  end
end
