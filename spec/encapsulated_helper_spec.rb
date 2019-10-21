# frozen_string_literal: true
require 'spec_helper'

describe Split::EncapsulatedHelper do
  include Split::EncapsulatedHelper


  def params
    raise NoMethodError, 'This method is not really defined'
  end

  describe "ab_test" do
    before do
      allow_any_instance_of(Split::EncapsulatedHelper::ContextShim).to receive(:ab_user)
      .and_return(mock_user)
    end

    it "should not raise an error when params raises an error" do
      expect{ params }.to raise_error(NoMethodError)
      expect(lambda { ab_test('link_color', 'blue', 'red') }).not_to raise_error
    end

    it "calls the block with selected alternative" do
      expect{|block| ab_test('link_color', 'red', 'red', &block) }.to yield_with_args('red', nil)
    end

    context "inside a view" do

      it "works inside ERB" do
        require 'erb'
        template = ERB.new(<<-ERB.split(/\s+/s).map(&:strip).join(' '), nil, "%")
          foo <% ab_test(:foo, '1', '2') do |alt, meta| %>
            static <%= alt %>
          <% end %>
        ERB
        expect(template.result(binding)).to match(/foo  static \d/)
      end

    end
  end

  describe "context" do
    it 'is passed in shim' do
      ctx = Class.new{
        include Split::EncapsulatedHelper
        public :session
      }.new
      expect(ctx).to receive(:session){{}}
      expect{ ctx.ab_test('link_color', 'blue', 'red') }.not_to raise_error
    end
  end
end
