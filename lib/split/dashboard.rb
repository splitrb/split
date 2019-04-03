# frozen_string_literal: true
require 'split'
require 'bigdecimal'
require 'split/dashboard/helpers'
require 'split/dashboard/pagination_helpers'
require 'pry'

module Split
  class Dashboard

    def call(env)
      @request = Rack::Request.new(env)
      if @request.path_info == '/'
        @params = @request.params
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
      else
        dir = File.dirname(File.expand_path(__FILE__))
        static_path = File.join(dir, 'dashboard', 'public')
        return Rack::File.new(static_path).call(env)
      end
    end

    def render_erb(view)
      [200, {}, [erb(view)]]
    end
    
    def erb(view, opts={})
      render_layout do
        partial(view, opts)
      end
    end

    def partial(view, opts={})
      dir = File.dirname(File.expand_path(__FILE__))
      filename = view.to_s + '.erb'
      file_path = File.join(dir, 'dashboard', 'views', filename)
      raw = File.read(file_path)
      b = binding
      (opts[:locals] || {}).each do |k,v| 
        b.local_variable_set(k, v)
      end
      p b.local_variables
      ERB.new(raw).result(b)
    end


    def render_layout(&block)
      partial(:layout, &block)
    end

    def redirect(url)
      [302, {'Location' => url}, []]
    end


    include Split::DashboardHelpers
    include Split::DashboardPaginationHelpers

    # get '/' do
    # end

    # post '/force_alternative' do
    #   Split::User.new(self)[params[:experiment]] = params[:alternative]
    #   redirect url('/')
    # end

    # post '/experiment' do
    #   @experiment = Split::ExperimentCatalog.find(params[:experiment])
    #   @alternative = Split::Alternative.new(params[:alternative], params[:experiment])
    #   @experiment.winner = @alternative.name
    #   redirect url('/')
    # end

    # post '/start' do
    #   @experiment = Split::ExperimentCatalog.find(params[:experiment])
    #   @experiment.start
    #   redirect url('/')
    # end

    # post '/reset' do
    #   @experiment = Split::ExperimentCatalog.find(params[:experiment])
    #   @experiment.reset
    #   redirect url('/')
    # end

    # post '/reopen' do
    #   @experiment = Split::ExperimentCatalog.find(params[:experiment])
    #   @experiment.reset_winner
    #   redirect url('/')
    # end

    # delete '/experiment' do
    #   @experiment = Split::ExperimentCatalog.find(params[:experiment])
    #   @experiment.delete
    #   redirect url('/')
    # end
  end
end
