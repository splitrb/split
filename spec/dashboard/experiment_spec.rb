# frozen_string_literal: true

require "spec_helper"
require "split/dashboard/experiment"

describe Split::DashboardExperiment do
  let(:experiment) { Split::ExperimentCatalog.find_or_create("link_color", "blue", "red") }
  let(:blue) { experiment.alternatives[0] }
  let(:red) { experiment.alternatives[1] }
  let(:view) { Split::DashboardExperiment.new(experiment) }

  describe "#extra_totals" do
    it "sums columns whose values are all numeric" do
      blue.record_extra_info("revenue", 10)
      blue.record_extra_info("clicks", 2)
      red.record_extra_info("revenue", 5)
      red.record_extra_info("clicks", 3)

      expect(view.extra_totals).to eq("revenue" => 15, "clicks" => 5)
    end

    it "reports N/A for non-numeric columns" do
      blue.record_extra_info("note", "first")
      red.record_extra_info("note", "second")

      expect(view.extra_totals).to eq("note" => "N/A")
    end

    it "reports N/A when a column mixes numbers with anything else" do
      blue.record_extra_info("revenue", 10)
      red.record_extra_info("revenue", "unknown")

      expect(view.extra_totals).to eq("revenue" => "N/A")
    end

    it "reports N/A when a column has no values at all" do
      blue.record_extra_info("revenue", nil)

      expect(view.extra_totals).to eq("revenue" => "N/A")
    end

    it "is empty when no alternative recorded extra info" do
      expect(view.extra_totals).to eq({})
    end
  end

  describe "#extra_columns" do
    it "unions columns across alternatives in first-seen order" do
      blue.record_extra_info("b", 1)
      red.record_extra_info("a", 2)
      red.record_extra_info("b", 3)

      expect(view.extra_columns).to eq(["b", "a"])
    end
  end

  describe "totals" do
    before do
      blue.participant_count = 10
      blue.set_completed_count(1)
      red.participant_count = 20
      red.set_completed_count(2)
    end

    it "sums participants across alternatives" do
      expect(view.total_participants).to eq(30)
    end

    it "sums completions across alternatives" do
      expect(view.total_completed).to eq(3)
    end

    it "sums unfinished participants across alternatives" do
      expect(view.total_unfinished).to eq(27)
    end
  end
end
