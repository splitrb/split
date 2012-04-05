require 'spec_helper'
require 'split/dashboard/helpers'

include Split::DashboardHelpers

describe Split::DashboardHelpers do
  describe 'confidence_level' do
    it 'should handle very small numbers' do
      confidence_level(Complex "2.222670197524858e-18-0.03629895899899249i").should eql('No Change')
    end
  end
end