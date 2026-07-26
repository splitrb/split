# frozen_string_literal: true

require "spec_helper"

describe Split::ExperimentCatalog do
  subject { Split::ExperimentCatalog }

  describe ".find_or_create" do
    it "should not raise an error when passed strings for alternatives" do
      expect { subject.find_or_create("xyz", "1", "2", "3") }.not_to raise_error
    end

    it "should not raise an error when passed an array for alternatives" do
      expect { subject.find_or_create("xyz", ["1", "2", "3"]) }.not_to raise_error
    end

    it "should raise the appropriate error when passed integers for alternatives" do
      expect { subject.find_or_create("xyz", 1, 2, 3) }.to raise_error(ArgumentError)
    end

    it "should raise the appropriate error when passed symbols for alternatives" do
      expect { subject.find_or_create("xyz", :a, :b, :c) }.to raise_error(ArgumentError)
    end

    it "should not raise error when passed an array for goals" do
      expect { subject.find_or_create({ "link_color" => ["purchase", "refund"] }, "blue", "red") }
          .not_to raise_error
    end

    it "should not raise error when passed just one goal" do
      expect { subject.find_or_create({ "link_color" => "purchase" }, "blue", "red") }
          .not_to raise_error
    end

    it "constructs a new experiment" do
      expect(subject.find_or_create("my_exp", "control me").control.to_s).to eq("control me")
    end
  end

  describe ".find" do
    it "should return an existing experiment" do
      experiment = Split::Experiment.new("basket_text", alternatives: ["blue", "red", "green"])
      experiment.save

      experiment = subject.find("basket_text")

      expect(experiment.name).to eq("basket_text")
    end

    it "should return nil if experiment not exist" do
      expect(subject.find("non_existent_experiment")).to be_nil
    end
  end

  describe ".all" do
    it "returns every registered experiment" do
      subject.find_or_create("link_color", "blue", "red")
      subject.find_or_create("button_size", "small", "big")

      expect(subject.all.map(&:name)).to match_array(%w[link_color button_size])
    end

    it "is empty when nothing is registered" do
      expect(subject.all).to eq([])
    end
  end

  describe ".all_active_first" do
    it "lists experiments without a winner first, each group sorted by name" do
      subject.find_or_create("b_active", "1", "2")
      subject.find_or_create("a_active", "1", "2")
      subject.find_or_create("c_finished", "1", "2").winner = "1"

      expect(subject.all_active_first.map(&:name)).to eq(%w[a_active b_active c_finished])
    end
  end
end
