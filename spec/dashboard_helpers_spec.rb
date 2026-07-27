# frozen_string_literal: true

require "spec_helper"
require "split/dashboard/helpers"

include Split::DashboardHelpers

describe Split::DashboardHelpers do
  describe "confidence_level" do
    it "should handle very small numbers" do
      expect(confidence_level(Complex(2e-18, -0.03))).to eq("Insufficient confidence")
    end

    it "should consider a z-score of 1.65 <= z < 1.96 as 90% confident" do
      expect(confidence_level(1.65)).to eq("90% confidence")
      expect(confidence_level(1.80)).to eq("90% confidence")
    end

    it "should consider a z-score of 1.96 <= z < 2.58 as 95% confident" do
      expect(confidence_level(1.96)).to eq("95% confidence")
      expect(confidence_level(2.00)).to eq("95% confidence")
    end

    it "should consider a z-score of z >= 2.58 as 99% confident" do
      expect(confidence_level(2.58)).to eq("99% confidence")
      expect(confidence_level(3.00)).to eq("99% confidence")
    end

    describe "#round" do
      it "can round number strings" do
        expect(round("3.1415")).to eq BigDecimal("3.14")
      end

      it "can round number strings for precsion" do
        expect(round("3.1415", 1)).to eq BigDecimal("3.1")
      end

      it "can handle invalid number strings" do
        expect(round("N/A")).to be_zero
      end
    end
  end

  describe "#extra_info_totals" do
    it "sums columns whose values are all numeric" do
      infos = [{ "revenue" => 10, "clicks" => 2 }, { "revenue" => 5, "clicks" => 3 }]

      expect(extra_info_totals(infos)).to eq("revenue" => 15, "clicks" => 5)
    end

    it "reports N/A for non-numeric columns" do
      infos = [{ "note" => "first" }, { "note" => "second" }]

      expect(extra_info_totals(infos)).to eq("note" => "N/A")
    end

    it "reports N/A when a column mixes numbers with anything else" do
      infos = [{ "revenue" => 10 }, { "revenue" => "unknown" }]

      expect(extra_info_totals(infos)).to eq("revenue" => "N/A")
    end

    it "reports N/A when a column has no values at all" do
      infos = [{ "revenue" => nil }, {}]

      expect(extra_info_totals(infos)).to eq("revenue" => "N/A")
    end

    it "unions columns across alternatives in first-seen order" do
      infos = [{ "b" => 1 }, { "a" => 2, "b" => 3 }]

      expect(extra_info_totals(infos).keys).to eq(["b", "a"])
    end

    it "is empty when no alternative recorded extra info" do
      expect(extra_info_totals([{}, {}])).to eq({})
    end
  end
end
