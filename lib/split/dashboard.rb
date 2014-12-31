require 'sinatra/base'
require 'split'
require 'bigdecimal'
require 'split/dashboard/helpers'

module Split
  class Dashboard < Sinatra::Base
    dir = File.dirname(File.expand_path(__FILE__))

    set :views,  "#{dir}/dashboard/views"
    set :public_folder, "#{dir}/dashboard/public"
    set :static, true
    set :method_override, true

    helpers Split::DashboardHelpers

    get '/' do
      # Display experiments without a winner at the top of the dashboard
      @experiments = Split::ExperimentCatalog.all_active_first

      @metrics = Split::Metric.all

      # Display Rails Environment mode (or Rack version if not using Rails)
      if Object.const_defined?('Rails')
        @current_env = Rails.env.titlecase
      else
        @current_env = "Rack: #{Rack.version}"
      end
      erb :index
    end

    post '/:experiment' do
      @experiment = Split::ExperimentCatalog.find(params[:experiment])
      @alternative = Split::Alternative.new(params[:alternative], params[:experiment])
      @experiment.winner = @alternative.name
      redirect url('/')
    end

    post '/start/:experiment' do
      @experiment = Split::ExperimentCatalog.find(params[:experiment])
      @experiment.start
      redirect url('/')
    end

    post '/reset/:experiment' do
      @experiment = Split::ExperimentCatalog.find(params[:experiment])
      @experiment.reset
      redirect url('/')
    end

    post '/reopen/:experiment' do
      @experiment = Split::ExperimentCatalog.find(params[:experiment])
      @experiment.reset_winner
      redirect url('/')
    end

    delete '/:experiment' do
      @experiment = Split::ExperimentCatalog.find(params[:experiment])
      @experiment.delete
      redirect url('/')
    end
  end
end
