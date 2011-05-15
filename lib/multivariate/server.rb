require 'rubygems'
require 'sinatra'
require 'bundler/setup'
require 'multivariate'


class TestApp < Sinatra::Base
  enable :sessions
  set :root, File.dirname(__FILE__)

  get '/' do
    @experiments = Multivariate::Experiment.all
    erb :index
  end
end