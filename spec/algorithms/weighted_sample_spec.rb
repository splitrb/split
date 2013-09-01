require "spec_helper"

describe Split::Algorithms::WeightedSample do
  it "should return an alternative" do
    experiment = Split::Experiment.find_or_create('link_color', {'blue' => 100}, {'red' => 0 })
    Split::Algorithms::WeightedSample.choose_alternative(experiment).class.should == Split::Alternative
  end

  it "should always return a heavily weighted option" do
    experiment = Split::Experiment.find_or_create('link_color', {'blue' => 100}, {'red' => 0 })
    Split::Algorithms::WeightedSample.choose_alternative(experiment).name.should == 'blue'
  end

  it "should return one of the results" do
    experiment = Split::Experiment.find_or_create('link_color', {'blue' => 1}, {'red' => 1 })
    ['red', 'blue'].should include Split::Algorithms::WeightedSample.choose_alternative(experiment).name
  end
end