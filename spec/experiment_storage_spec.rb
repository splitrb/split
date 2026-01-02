# frozen_string_literal: true

require "spec_helper"

describe Split::ExperimentStorage do
  let(:experiment) do
    {
      resettable: "false",
      algorithm: "Split::Algorithms::WeightedSample",
      alternatives: [ "foo", "bar" ],
      goals: ["purchase", "refund"],
      metadata: {
        "foo" => { "text" => "Something bad" },
        "bar" => { "text" => "Something good" }
      }
    }
  end
  before do
    Split.configuration.experiments = {
      my_exp: experiment
    }
  end

  context "ConfigStorage" do
    let(:config_store) { Split::ExperimentStorage::ConfigStorage.new("my_exp") }

    it "loads an experiment from the configuration" do
      stored_data = config_store.load
      expect(stored_data).to match(experiment)
    end

    it "checks if an experiment exists on the configuration" do
      expect(config_store.exists?).to be_truthy
      expect(Split::ExperimentStorage::ConfigStorage.new("whatever").exists?).to be_falsy
    end

    it "memoizes data from the configuration by default" do
      expect(config_store).to receive(:load!).once.and_call_original
      config_store.load
      config_store.load
    end
  end

  context "from Redis" do
    before { Split::ExperimentCatalog.find_or_create(:my_exp) }
    let(:config_store) { Split::ExperimentStorage::RedisStorage.new("my_exp") }

    it "loads an experiment from the configuration" do
      stored_data = config_store.load
      stored_data[:alternatives].map! { |alternative| alternative.name }
      expect(stored_data).to match(experiment)
    end

    it "checks if an experiment exists on the configuration" do
      expect(config_store.exists?).to be_truthy
      expect(Split::ExperimentStorage::ConfigStorage.new("whatever").exists?).to be_falsy
    end
  end
end
