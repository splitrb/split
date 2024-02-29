# frozen_string_literal: true

require "spec_helper"

describe Split::EncapsulatedHelper do
  include Split::EncapsulatedHelper

  describe "ab_test" do
    before do
      allow_any_instance_of(Split::EncapsulatedHelper::ContextShim).to receive(:ab_user)
      .and_return(mock_user)
    end

    context "when params raises an error" do
      before do
        allow(self).to receive(:params).and_raise(NoMethodError)
      end

      it "should not raise an error " do
        expect { params }.to raise_error(NoMethodError)
        expect { ab_test("link_color", "blue", "red") }.not_to raise_error
      end
    end

    it "calls the block with selected alternative" do
      expect { |block| ab_test("link_color", "red", "red", &block) }.to yield_with_args("red", {})
    end

    context "inside a view" do
      it "works inside ERB" do
        require "erb"
        template = ERB.new(<<-ERB.split(/\s+/s).map(&:strip).join(" "), nil, "%")
          foo <% ab_test(:foo, '1', '2') do |alt, meta| %>
            static <%= alt %>
          <% end %>
        ERB
        expect(template.result(binding)).to match(/foo  static \d/)
      end
    end
  end

  describe "context" do
    it "is passed in shim" do
      ctx = Class.new {
        include Split::EncapsulatedHelper
        public :session
      }.new

      expect(ctx).to receive(:session) { {} }
      expect { ctx.ab_test("link_color", "blue", "red") }.not_to raise_error
    end

    context "when request is defined in context of ContextShim" do
      context "when overriding by params" do
        it do
          ctx = Class.new {
            public :session
            def request
              build_request(params: {
                "ab_test" => { "link_color" => "blue" }
              })
            end
          }.new

          context_shim = Split::EncapsulatedHelper::ContextShim.new(ctx)
          expect(context_shim.ab_test("link_color", "blue", "red")).to be("blue")
        end
      end

      context "when overriding by cookies" do
        it do
          ctx = Class.new {
            public :session
            def request
              build_request(cookies: {
                "split_override" => '{ "link_color": "red" }'
              })
            end
          }.new

          context_shim = Split::EncapsulatedHelper::ContextShim.new(ctx)
          expect(context_shim.ab_test("link_color", "blue", "red")).to be("red")
        end
      end
    end
  end
end
