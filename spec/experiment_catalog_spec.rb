require 'spec_helper'

describe Split::ExperimentCatalog do
  subject { Split::ExperimentCatalog }

  describe ".find_or_create" do
    it "should not raise an error when passed strings for alternatives" do
      expect { subject.find_or_create('xyz', '1', '2', '3') }.not_to raise_error
    end

    it "should not raise an error when passed an array for alternatives" do
      expect { subject.find_or_create('xyz', ['1', '2', '3']) }.not_to raise_error
    end

    it "should raise the appropriate error when passed integers for alternatives" do
      expect { subject.find_or_create('xyz', 1, 2, 3) }.to raise_error
    end

    it "should raise the appropriate error when passed symbols for alternatives" do
      expect { subject.find_or_create('xyz', :a, :b, :c) }.to raise_error
    end

    it "should not raise error when passed an array for goals" do
      expect { subject.find_or_create({'link_color' => ["purchase", "refund"]}, 'blue', 'red') }
          .not_to raise_error
    end

    it "should not raise error when passed just one goal" do
      expect { subject.find_or_create({'link_color' => "purchase"}, 'blue', 'red') }
          .not_to raise_error
    end

    it "constructs a new experiment" do
      expect(subject.find_or_create('my_exp', 'control me').control.to_s).to eq('control me')
    end
  end
end
