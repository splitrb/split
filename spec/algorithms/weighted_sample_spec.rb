# frozen_string_literal: true
require 'spec_helper'

describe Split::Algorithms::WeightedSample do
  before(:example) do
    Split.configuration.experiments = {
      link_color: {
        alternatives: [
          { name: 'blue', percent: 90 },
          { name: 'red', percent: 10 }
        ]
      }
    }
  end

  it 'should return an alternative' do
    experiment = Split::ExperimentCatalog.find_or_create('link_color')
    expect(Split::Algorithms::WeightedSample.choose_alternative(experiment).class).to eq(Split::Alternative)
  end

  it 'should always return a heavily weighted option' do
    experiment = Split::ExperimentCatalog.find_or_create('link_color')
    expect(Split::Algorithms::WeightedSample.choose_alternative(experiment).name).to eq('blue')
  end

  it 'should return one of the results' do
    experiment = Split::ExperimentCatalog.find_or_create('link_color')
    expect(%w(red blue)).to include Split::Algorithms::WeightedSample.choose_alternative(experiment).name
  end
end
