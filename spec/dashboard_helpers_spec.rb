require 'spec_helper'
require 'split/dashboard/helpers'

include Split::DashboardHelpers

describe Split::DashboardHelpers do
  describe 'confidence_level' do
    it 'should handle very small numbers' do
      confidence_level(0.000000000000006).should eql('No Change')
    end
  end
end