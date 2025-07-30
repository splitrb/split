# frozen_string_literal: true

ENV["RACK_ENV"] = "test"

require "rubygems"
require "bundler/setup"

require "simplecov"
SimpleCov.start

require "split"
require "yaml"
require "pry"

Dir["./spec/support/*.rb"].each { |f| require f }

module GlobalSharedContext
  extend RSpec::SharedContext
  let(:mock_user) { Split::User.new(double(session: {})) }

  before(:each) do
    Split.configuration = Split::Configuration.new
    Split.redis = Redis.new
    Split.redis.select(10)
    Split.redis.flushdb
    Split::Cache.clear
    @ab_user = mock_user
    @params = nil
  end
end

RSpec.configure do |config|
  config.order = "random"
  config.include GlobalSharedContext
  config.raise_errors_for_deprecations!
end

def session
  @session ||= {}
end

def params
  @params ||= {}
end

def request
  @request ||= build_request
end

DummyRequest = Struct.new(:user_agent, :ip, :params, :cookies, :headers)

def build_request(
  user_agent: "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_6; de-de) AppleWebKit/533.20.25 (KHTML, like Gecko) Version/5.0.4 Safari/533.20.27",
  ip: "192.168.1.1",
  params: {},
  cookies: {},
  headers: {}
)
  r = DummyRequest.new
  r.user_agent = user_agent
  r.ip = ip
  r.params = params
  r.cookies = cookies
  r.headers = headers
  r
end
