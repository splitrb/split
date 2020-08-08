# frozen_string_literal: true

require 'split'
require 'bigdecimal'
require 'split/dashboard/routing'
require 'split/dashboard/rendering'
require 'split/dashboard/action'

module Split
  class Dashboard
    class Web
      include Routing
      include Rendering

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
        experiment = Split::ExperimentCatalog.find(params['experiment'])
        alternative = Split::Alternative.new(params['alternative'], experiment.name)

        cookies = JSON.parse(request.cookies['split_override']) rescue {}
        cookies[experiment.name] = alternative.name
        response.set_cookie('split_override', { value: cookies.to_json, path: '/' })
        redirect url('/')
      end

      post '/experiment' do
        @experiment = Split::ExperimentCatalog.find(params['experiment'])
        @alternative = Split::Alternative.new(params['alternative'], params['experiment'])
        @experiment.winner = @alternative.name
        redirect url('/')
      end

      post '/start' do
        @experiment = Split::ExperimentCatalog.find(params['experiment'])
        @experiment.start
        redirect url('/')
      end

      post '/reset' do
        @experiment = Split::ExperimentCatalog.find(params['experiment'])
        @experiment.reset
        redirect url('/')
      end

      post '/reopen' do
        @experiment = Split::ExperimentCatalog.find(params['experiment'])
        @experiment.reset_winner
        redirect url('/')
      end

      post '/update_cohorting' do
        @experiment = Split::ExperimentCatalog.find(params['experiment'])
        case params['cohorting_action'].downcase
        when "enable"
          @experiment.enable_cohorting
        when "disable"
          @experiment.disable_cohorting
        end
        redirect url('/')
      end

      delete '/experiment' do
        @experiment = Split::ExperimentCatalog.find(params['experiment'])
        @experiment.delete
        redirect url('/')
      end
    end
  end
end
