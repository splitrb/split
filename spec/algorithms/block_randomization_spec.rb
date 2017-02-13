require "spec_helper"

describe Split::Algorithms::BlockRandomization do

  let(:experiment) { Split::Experiment.new 'experiment' }
  let(:alternative_A) { Split::Alternative.new 'A', 'experiment' }
  let(:alternative_B) { Split::Alternative.new 'B', 'experiment' }
  let(:alternative_C) { Split::Alternative.new 'C', 'experiment' }

  before :each do
    allow(experiment).to receive(:alternatives) { [alternative_A, alternative_B, alternative_C] }
  end

  it "should return an alternative" do
    expect(Split::Algorithms::BlockRandomization.choose_alternative(experiment).class).to eq(Split::Alternative)
  end

  it "should always return the minimum participation option" do
    allow(alternative_A).to receive(:participant_count) { 1 }
    allow(alternative_B).to receive(:participant_count) { 1 }
    allow(alternative_C).to receive(:participant_count) { 0 }
    expect(Split::Algorithms::BlockRandomization.choose_alternative(experiment)).to eq(alternative_C)
  end

  it "should return one of the minimum participation options when multiple" do
    allow(alternative_A).to receive(:participant_count) { 0 }
    allow(alternative_B).to receive(:participant_count) { 0 }
    allow(alternative_C).to receive(:participant_count) { 0 }
    alternative = Split::Algorithms::BlockRandomization.choose_alternative(experiment)
    expect([alternative_A, alternative_B, alternative_C].include?(alternative)).to be(true)
  end
end
