# frozen_string_literal: true

require "spec_helper"
require "split/dashboard/experiment"

describe Split::DashboardAlternative do
  let(:experiment) { Split::ExperimentCatalog.find_or_create("link_color", "blue", "red") }
  let(:control) { experiment.alternatives[0] }
  let(:alternative) { experiment.alternatives[1] }

  def view_for(alternative)
    Split::DashboardAlternative.new(alternative, experiment)
  end

  describe "#conversion_delta" do
    before do
      control.participant_count = 100
      control.set_completed_count(10)
      alternative.participant_count = 100
    end

    it "is nil for the control" do
      expect(view_for(control).conversion_delta).to be_nil
    end

    it "is positive when the alternative beats the control" do
      alternative.set_completed_count(15)

      expect(view_for(alternative).conversion_delta).to be_within(0.0001).of(0.5)
    end

    it "is negative when the alternative loses to the control" do
      alternative.set_completed_count(5)

      expect(view_for(alternative).conversion_delta).to eq(-0.5)
    end

    it "is nil when the rates match" do
      alternative.set_completed_count(10)

      expect(view_for(alternative).conversion_delta).to be_nil
    end

    it "is nil when the control has not converted" do
      control.set_completed_count(0)
      alternative.set_completed_count(5)

      expect(view_for(alternative).conversion_delta).to be_nil
    end
  end

  describe "counts" do
    before do
      alternative.participant_count = 10
      alternative.set_completed_count(4)
    end

    it "reads the counts once, when built" do
      view = view_for(alternative)
      alternative.participant_count = 999

      expect(view.participants).to eq(10)
      expect(view.completed).to eq(4)
      expect(view.unfinished).to eq(6)
    end
  end
end
