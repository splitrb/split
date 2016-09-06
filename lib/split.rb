# frozen_string_literal: true
%w[algorithms
   alternative
   configuration
   exceptions
   experiment
   experiment_catalog
   extensions
   goals_collection
   helper
   metric
   persistence
   encapsulated_helper
   redis_interface
   trial
   user
   version
   zscore].each do |f|
  require "split/#{f}"
end

require 'split/engine' if defined?(Rails)

module Split
  extend self
  attr_accessor :configuration

  # Accepts:
  #   1. A redis URL (valid for `Redis.new(url: url)`)
  #   2. an options hash compatible with `Redis.new`
  #   3. or a valid Redis instance (one that responds to `#smembers`). Likely,
  #      this will be an instance of either `Redis`, `Redis::Client`,
  #      `Redis::DistRedis`, or `Redis::Namespace`.
  def redis=(server)
    @redis = if server.is_a?(String)
      Redis.new(:url => server, :thread_safe => true)
    elsif server.is_a?(Hash)
      Redis.new(server.merge(:thread_safe => true))
    elsif server.respond_to?(:smembers)
      server
    else
      raise ArgumentError,
        "You must supply a url, options hash or valid Redis connection instance"
    end
  end

  # Returns the current Redis connection. If none has been created, will
  # create a new one.
  def redis
    return @redis if @redis
    self.redis = self.configuration.redis
    self.redis
  end

  # Call this method to modify defaults in your initializers.
  #
  # @example
  #   Split.configure do |config|
  #     config.ignore_ip_addresses = '192.168.2.1'
  #   end
  def configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end
end

Split.configure {}
