# frozen_string_literal: true
require 'redis'

require 'split/algorithms/block_randomization'
require 'split/algorithms/weighted_sample'
require 'split/algorithms/whiplash'
require 'split/alternative'
require 'split/configuration'
require 'split/encapsulated_helper'
require 'split/exceptions'
require 'split/experiment'
require 'split/experiment_catalog'
require 'split/extensions/string'
require 'split/goals_collection'
require 'split/helper'
require 'split/combined_experiments_helper'
require 'split/metric'
require 'split/persistence'
require 'split/redis_interface'
require 'split/trial'
require 'split/user'
require 'split/version'
require 'split/zscore'
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
      Redis.new(url: server)
    elsif server.is_a?(Hash)
      Redis.new(server)
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

# Check to see if being run in a Rails application.  If so, wait until before_initialize to run configuration so Gems that create ENV variables have the chance to initialize first.
if defined?(::Rails)
  class Railtie < Rails::Railtie
    config.before_initialize { Split.configure {} }
  end
else
  Split.configure {}
end
