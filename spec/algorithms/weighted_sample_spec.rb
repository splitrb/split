require "spec_helper"

describe Split::Algorithms::WeightedSample do
  it "should return an alternative" do
    experiment = Split::ExperimentCatalog.find_or_create('link_color', {'blue' => 100}, {'red' => 0 })
    expect(Split::Algorithms::WeightedSample.choose_alternative(experiment).class).to eq(Split::Alternative)
  end

  it "should always return a heavily weighted option" do
    experiment = Split::ExperimentCatalog.find_or_create('link_color', {'blue' => 100}, {'red' => 0 })
    expect(Split::Algorithms::WeightedSample.choose_alternative(experiment).name).to eq('blue')
  end

  it "should return one of the results" do
    experiment = Split::ExperimentCatalog.find_or_create('link_color', {'blue' => 1}, {'red' => 1 })
    expect(['red', 'blue']).to include Split::Algorithms::WeightedSample.choose_alternative(experiment).name
  end
end
