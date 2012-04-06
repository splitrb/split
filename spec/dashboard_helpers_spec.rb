require 'spec_helper'
require 'split/dashboard/helpers'

include Split::DashboardHelpers

describe Split::DashboardHelpers do
  describe 'confidence_level' do
    it 'should handle very small numbers' do
      confidence_level(Complex(2e-18, -0.03)).should eql('No Change')
    end
  end
end