require 'rubygems'
require 'multivariate/experiment'
require 'multivariate/alternative'
require 'multivariate/helper'

require 'redis'
REDIS = Redis.new

# detect if its been loaded by rails
  # hook helpers into action controller and action view
# else detect if loaded by sinatra
  # and add mixin code for sinatra

# the loaded framework also needs to define a method for loading and storing the session of the user