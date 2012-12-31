require "spec_helper"

describe Split::Algorithms::Whiplash do
  
  it "should return one of the results" do
    experiment = Split::Experiment.find_or_create('link_color', {'blue' => 1}, {'red' => 1 })
    ['red', 'blue'].should include Split::Algorithms::Whiplash.choose_alternative(experiment).name
  end
  
  it "should guess floats" do
    Split::Algorithms::Whiplash.send(:arm_guess, 0, 0).class.should == Float
    Split::Algorithms::Whiplash.send(:arm_guess, 1, 0).class.should == Float
    Split::Algorithms::Whiplash.send(:arm_guess, 2, 1).class.should == Float
    Split::Algorithms::Whiplash.send(:arm_guess, 1000, 5).class.should == Float
    Split::Algorithms::Whiplash.send(:arm_guess, 10, -2).class.should == Float
  end
  
end