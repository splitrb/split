require 'spec_helper'
require 'split/metric'

describe Split::Metric do
  describe 'possible experiments' do
    it "should load the experiment if there is one, but no metric" do
      experiment = Split::ExperimentCatalog.find_or_create('color', 'red', 'blue')
      expect(Split::Metric.possible_experiments('color')).to eq([experiment])
    end

    it "should load the experiments in a metric" do
      experiment1 = Split::ExperimentCatalog.find_or_create('color', 'red', 'blue')
      experiment2 = Split::ExperimentCatalog.find_or_create('size', 'big', 'small')

      metric = Split::Metric.new(:name => 'purchase', :experiments => [experiment1, experiment2])
      metric.save
      expect(Split::Metric.possible_experiments('purchase')).to include(experiment1, experiment2)
    end

    it "should load both the metric experiments and an experiment with the same name" do
      experiment1 = Split::ExperimentCatalog.find_or_create('purchase', 'red', 'blue')
      experiment2 = Split::ExperimentCatalog.find_or_create('size', 'big', 'small')

      metric = Split::Metric.new(:name => 'purchase', :experiments => [experiment2])
      metric.save
      expect(Split::Metric.possible_experiments('purchase')).to include(experiment1, experiment2)
    end
  end

end
