require 'spec_helper'
require 'split/dashboard/helpers'

include Split::DashboardHelpers

describe Split::DashboardHelpers do
  describe 'confidence_level' do
    it 'should handle very small numbers' do
      confidence_level(Complex(2e-18, -0.03)).should eql('Insufficient confidence')
    end

    it "should consider a z-score of 1.65 <= z < 1.96 as 90% confident" do
      confidence_level(1.65).should eql('90% confidence')
      confidence_level(1.80).should eql('90% confidence')
    end

    it "should consider a z-score of 1.96 <= z < 2.58 as 95% confident" do
      confidence_level(1.96).should eql('95% confidence')
      confidence_level(2.00).should eql('95% confidence')
    end

    it "should consider a z-score of z >= 2.58 as 99% confident" do
      confidence_level(2.58).should eql('99% confidence')
      confidence_level(3.00).should eql('99% confidence')
    end
  end
end
