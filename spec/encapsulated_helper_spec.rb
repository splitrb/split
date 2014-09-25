require 'spec_helper'

describe Split::EncapsulatedHelper do
  include Split::EncapsulatedHelper

  before do
    @persistence_adapter = Split.configuration.persistence
    Split.configuration.persistence = Hash
  end

  after do
    Split.configuration.persistence = @persistence_adapter
  end

  def params
    raise NoMethodError, 'This method is not really defined'
  end

  describe "ab_test" do
    it "should not raise an error when params raises an error" do
      expect(lambda { ab_test('link_color', 'blue', 'red') }).not_to raise_error
    end
  end
end
