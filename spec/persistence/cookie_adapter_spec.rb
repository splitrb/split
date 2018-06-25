# frozen_string_literal: true
require "spec_helper"
require 'rack/test'

describe Split::Persistence::CookieAdapter do
  subject { described_class.new(context) }

  shared_examples "sets cookies correctly" do
    describe "#[] and #[]=" do
      it "set and return the value for given key" do
        subject["my_key"] = "my_value"
        expect(subject["my_key"]).to eq("my_value")
      end

      it "handles invalid JSON" do
        context.request.cookies[:split] = {
          :value => '{"foo":2,',
          :expires => Time.now
        }
        expect(subject["my_key"]).to be_nil
        subject["my_key"] = "my_value"
        expect(subject["my_key"]).to eq("my_value")
      end
    end

    describe "#delete" do
      it "should delete the given key" do
        subject["my_key"] = "my_value"
        subject.delete("my_key")
        expect(subject["my_key"]).to be_nil
      end
    end

    describe "#keys" do
      it "should return an array of the session's stored keys" do
        subject["my_key"] = "my_value"
        subject["my_second_key"] = "my_second_value"
        expect(subject.keys).to match(["my_key", "my_second_key"])
      end
    end
  end


  context "when using Rack" do
    let(:env) { Rack::MockRequest.env_for("http://example.com:8080/") }
    let(:request) { Rack::Request.new(env) }
    let(:response) { Rack::MockResponse.new(200, {}, "") }
    let(:context) { double(request: request, response: response, cookies: CookiesMock.new) }

    include_examples "sets cookies correctly"

    it "puts multiple experiments in a single cookie" do
      subject["foo"] = "FOO"
      subject["bar"] = "BAR"
      expect(context.response.headers["Set-Cookie"]).to match(/\Asplit=%7B%22foo%22%3A%22FOO%22%2C%22bar%22%3A%22BAR%22%7D; path=\/; expires=[a-zA-Z]{3}, \d{2} [a-zA-Z]{3} \d{4} \d{2}:\d{2}:\d{2} -0000\Z/)
    end

    it "ensure other added cookies are not overriden" do
      context.response.set_cookie 'dummy', 'wow'
      subject["foo"] = "FOO"
      expect(context.response.headers["Set-Cookie"]).to include("dummy=wow")
      expect(context.response.headers["Set-Cookie"]).to include("split=")
    end
  end

  context "when @context is an ActionController::Base" do
    before :context do
      require "rails"
      require "action_controller/railtie"
    end

    let(:context) do
      controller = controller_class.new
      if controller.respond_to?(:set_request!)
        controller.set_request!(ActionDispatch::Request.new({}))
      else # Before rails 5.0
        controller.send(:"request=", ActionDispatch::Request.new({}))
      end

      response = ActionDispatch::Response.new(200, {}, '').tap do |res|
        res.request = controller.request
      end

      if controller.respond_to?(:set_response!)
        controller.set_response!(response)
      else # Before rails 5.0
        controller.send(:set_response!, response)
      end
      controller
    end

    let(:controller_class) { Class.new(ActionController::Base) }

    include_examples "sets cookies correctly"

    it "puts multiple experiments in a single cookie" do
      subject["foo"] = "FOO"
      subject["bar"] = "BAR"
      expect(subject.keys).to eq(["foo", "bar"])
      expect(subject["foo"]).to eq("FOO")
      expect(subject["bar"]).to eq("BAR")
      cookie_jar = context.request.env["action_dispatch.cookies"]
      expect(cookie_jar['split']).to eq("{\"foo\":\"FOO\",\"bar\":\"BAR\"}")
    end
  end
end
