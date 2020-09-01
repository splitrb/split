# frozen_string_literal: true
require 'spec_helper'
require 'split/dashboard/helpers'

include Split::DashboardHelpers

describe Split::DashboardHelpers do
  describe 'confidence_level' do
    it 'should handle very small numbers' do
      expect(confidence_level(Complex(2e-18, -0.03))).to eq('Insufficient confidence')
    end

    it "should consider a z-score of 1.65 <= z < 1.96 as 90% confident" do
      expect(confidence_level(1.65)).to eq('90% confidence')
      expect(confidence_level(1.80)).to eq('90% confidence')
    end

    it "should consider a z-score of 1.96 <= z < 2.58 as 95% confident" do
      expect(confidence_level(1.96)).to eq('95% confidence')
      expect(confidence_level(2.00)).to eq('95% confidence')
    end

    it "should consider a z-score of z >= 2.58 as 99% confident" do
      expect(confidence_level(2.58)).to eq('99% confidence')
      expect(confidence_level(3.00)).to eq('99% confidence')
    end

    describe '#round' do
      it 'can round number strings' do
        expect(round('3.1415')).to eq BigDecimal('3.14')
      end

      it 'can round number strings for precsion' do
        expect(round('3.1415', 1)).to eq BigDecimal('3.1')
      end

      it 'can handle invalid number strings' do
        expect(round('N/A')).to be_zero
      end
    end
  end
end
