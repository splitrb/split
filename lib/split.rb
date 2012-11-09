%w[experiment alternative helper version configuration backend error].each do |f|
  require "split/#{f}"
end

require 'split/engine' if defined?(Rails)
require 'redis/namespace'
require 'time'


module Split
  extend self
  attr_accessor :configuration

  # Call this method to modify defaults in your initializers.
  #
  # @example
  #   Split.configure do |config|
  #     config.ignore_ips = '192.168.2.1'
  #   end
  def configure
     self.configuration ||= Configuration.new
     yield(configuration)
   end
   
   def backend
     @backend ||= Split::Backend.new
   end
end

Split.configure {}