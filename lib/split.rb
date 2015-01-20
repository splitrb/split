%w[algorithms
   alternative
   configuration
   exceptions
   experiment
   experiment_catalog
   extensions
   helper
   metric
   persistence
   encapsulated_helper
   trial
   version
   zscore].each do |f|
  require "split/#{f}"
end

require 'split/engine' if defined?(Rails)
require 'redis/namespace'

module Split
  extend self
  attr_accessor :configuration

  # Accepts:
  #   1. A 'hostname:port' string
  #   2. A 'hostname:port:db' string (to select the Redis db)
  #   3. A 'hostname:port/namespace' string (to set the Redis namespace)
  #   4. A redis URL string 'redis://host:port'
  #   5. An instance of `Redis`, `Redis::Client`, `Redis::DistRedis`,
  #      or `Redis::Namespace`.
  def redis=(server)
    if server.respond_to? :split
      if server["redis://"]
        redis = Redis.connect(:url => server, :thread_safe => true)
      else
        server, namespace = server.split('/', 2)
        host, port, db = server.split(':')
        redis = Redis.new(:host => host, :port => port,
          :thread_safe => true, :db => db)
      end
      namespace ||= :split

      @redis = Redis::Namespace.new(namespace, :redis => redis)
    elsif server.respond_to? :namespace=
      @redis = server
    else
      @redis = Redis::Namespace.new(:split, :redis => server)
    end
  end

  # Returns the current Redis connection. If none has been created, will
  # create a new one.
  def redis
    return @redis if @redis
    self.redis = ENV.fetch('REDIS_URL', 'localhost:6379')
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
