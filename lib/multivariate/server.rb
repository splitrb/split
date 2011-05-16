require 'sinatra/base'
require 'multivariate'

module Multivariate
  class Server < Sinatra::Base
    enable :sessions
    dir = File.dirname(File.expand_path(__FILE__))
    set :views,  "#{dir}/server/views"

    get '/' do
      @experiments = Multivariate::Experiment.all
      render 'hello'
    end
  end
end