# frozen_string_literal: true
require 'split'
require 'bigdecimal'
require 'split/dashboard/routing'
require 'split/dashboard/rendering'

module Split
  class Dashboard

    include Routing
    include Rendering

    STATIC_RACK = Rack::File.new(
      File.join(
        File.dirname(File.expand_path(__FILE__)),
        'dashboard',
        'public'
      )
    )

    def call(env)
      @request = Rack::Request.new(env)
      if proc = self.class.route_for(@request.request_method, @request.path_info)
        @params = @request.params
        return instance_eval(&proc)
      end
      return STATIC_RACK.call(env)
    end

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
      render_erb :index
    end

    post '/force_alternative' do
      Split::User.new(@request)[@params['experiment']] = @params['alternative']
      redirect url('/')
    end

    post '/experiment' do
      @experiment = Split::ExperimentCatalog.find(@params['experiment'])
      @alternative = Split::Alternative.new(@params['alternative'], @params['experiment'])
      @experiment.winner = @alternative.name
      redirect url('/')
    end

    post '/start' do
      @experiment = Split::ExperimentCatalog.find(@params['experiment'])
      @experiment.start
      redirect url('/')
    end

    post '/reset' do
      @experiment = Split::ExperimentCatalog.find(@params['experiment'])
      @experiment.reset
      redirect url('/')
    end

    post '/reopen' do
      @experiment = Split::ExperimentCatalog.find(@params['experiment'])
      @experiment.reset_winner
      redirect url('/')
    end

    delete '/experiment' do
      @experiment = Split::ExperimentCatalog.find(@params['experiment'])
      @experiment.delete
      redirect url('/')
    end
  end
end
