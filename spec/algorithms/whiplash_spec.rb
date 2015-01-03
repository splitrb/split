require "spec_helper"

describe Split::Algorithms::Whiplash do

  it "should return an algorithm" do
    experiment = Split::ExperimentCatalog.find_or_create('link_color', {'blue' => 1}, {'red' => 1 })
    expect(Split::Algorithms::Whiplash.choose_alternative(experiment).class).to eq(Split::Alternative)
  end

  it "should return one of the results" do
    experiment = Split::ExperimentCatalog.find_or_create('link_color', {'blue' => 1}, {'red' => 1 })
    expect(['red', 'blue']).to include Split::Algorithms::Whiplash.choose_alternative(experiment).name
  end

  it "should guess floats" do
    expect(Split::Algorithms::Whiplash.send(:arm_guess, 0, 0).class).to eq(Float)
    expect(Split::Algorithms::Whiplash.send(:arm_guess, 1, 0).class).to eq(Float)
    expect(Split::Algorithms::Whiplash.send(:arm_guess, 2, 1).class).to eq(Float)
    expect(Split::Algorithms::Whiplash.send(:arm_guess, 1000, 5).class).to eq(Float)
    expect(Split::Algorithms::Whiplash.send(:arm_guess, 10, -2).class).to eq(Float)
  end

end
