# frozen_string_literal: true
require 'spec_helper'
require 'split/combined_experiments_helper'

describe Split::CombinedExperimentsHelper do
  include Split::CombinedExperimentsHelper

  describe 'ab_combined_test' do
    let!(:config_enabled) { true }
    let!(:combined_experiments) { [:exp_1_click, :exp_1_scroll ]}
    let!(:allow_multiple_experiments) { true }

    before do
      Split.configuration.experiments = {
        :combined_exp_1 => {
          :alternatives => [ {"control"=> 0.5}, {"test-alt"=> 0.5} ],
          :metric => :my_metric,
          :combined_experiments => combined_experiments
        }
      }
      Split.configuration.enabled = config_enabled
      Split.configuration.allow_multiple_experiments = allow_multiple_experiments
    end

    context 'without config enabled' do
      let!(:config_enabled) { false }

      it "raises an error" do
        expect(lambda { ab_combined_test :combined_exp_1 }).to raise_error(Split::InvalidExperimentsFormatError )
      end
    end

    context 'multiple experiments disabled' do
      let!(:allow_multiple_experiments) { false }

      it "raises an error if multiple experiments is disabled" do
        expect(lambda { ab_combined_test :combined_exp_1 }).to raise_error(Split::InvalidExperimentsFormatError)
      end
    end

    context 'without combined experiments' do
      let!(:combined_experiments) { nil }

      it "raises an error" do
        expect(lambda { ab_combined_test :combined_exp_1 }).to raise_error(Split::InvalidExperimentsFormatError )
      end
    end

    it "uses same alternative for all sub experiments and returns the alternative" do
      allow(self).to receive(:get_alternative) { "test-alt" }
      expect(self).to receive(:ab_test).with(:exp_1_click, {"control"=>0.5}, {"test-alt"=>0.5}) { "test-alt" }
      expect(self).to receive(:ab_test).with(:exp_1_scroll, [{"control" => 0, "test-alt" => 1}])

      expect(ab_combined_test('combined_exp_1')).to eq('test-alt')
    end
  end
end
