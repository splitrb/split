# frozen_string_literal: true
require 'sinatra/base'
require 'split'
require 'bigdecimal'
require 'split/dashboard/helpers'

module Split
  class Dashboard < Sinatra::Base
    dir = File.dirname(File.expand_path(__FILE__))

    set :views, "#{dir}/dashboard/views"
    set :public_folder, "#{dir}/dashboard/public"
    set :static, true
    set :method_override, true

    helpers Split::DashboardHelpers

    get '/' do
      # Display experiments without a winner at the top of the dashboard
      @experiments = Split::ExperimentCatalog.all_active_first

      erb :index
    end

    get '/experiments/:name' do
      @experiment = Split::ExperimentCatalog.find(params[:name])
      redirect url('/') unless @experiment

      @metrics = Split::Metric.all
      @scores = Split::Score.all

      erb :'experiments/show'
    end

    post '/force_alternative' do
      Split::User.new(self)[params[:experiment]] = params[:alternative]
      redirect url("/experiments/#{params[:experiment]}")
    end

    post '/experiment' do
      @experiment = Split::ExperimentCatalog.find(params[:experiment])
      @alternative = Split::Alternative.new(params[:alternative], params[:experiment])
      @experiment.winner = @alternative.name
      redirect url("/experiments/#{params[:experiment]}")
    end

    post '/start' do
      @experiment = Split::ExperimentCatalog.find(params[:experiment])
      @experiment.start
      redirect url("/experiments/#{params[:experiment]}")
    end

    post '/reset' do
      @experiment = Split::ExperimentCatalog.find(params[:experiment])
      @experiment.reset
      redirect url("/experiments/#{params[:experiment]}")
    end

    post '/reopen' do
      @experiment = Split::ExperimentCatalog.find(params[:experiment])
      @experiment.reset_winner
      redirect url("/experiments/#{params[:experiment]}")
    end

    delete '/experiment' do
      @experiment = Split::ExperimentCatalog.find(params[:experiment])
      @experiment.delete
      redirect url("/experiments/#{params[:experiment]}")
    end
  end
end
