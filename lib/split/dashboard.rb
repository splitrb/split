require 'sinatra/base'
require 'split'
require 'bigdecimal'

module Split
  class Dashboard < Sinatra::Base
    dir = File.dirname(File.expand_path(__FILE__))

    set :views,  "#{dir}/dashboard/views"
    set :public, "#{dir}/dashboard/public"
    set :static, true
    set :method_override, true

    helpers do
      def url(*path_parts)
        [ path_prefix, path_parts ].join("/").squeeze('/')
      end

      def path_prefix
        request.env['SCRIPT_NAME']
      end

      def number_to_percentage(number, precision = 2)
        round(number * 100)
      end

      def round(number, precision = 2)
        BigDecimal.new(number.to_s).round(precision).to_f
      end

      def confidence_level(z_score)
        z = z_score.to_f
        if z > 0.0
          if z < 1.96
            'no confidence'
          elsif z < 2.57
            '95% confidence'
          elsif z < 3.29
            '99% confidence'
          else
            '99.9% confidence'
          end
        elsif z < 0.0
          if z > -1.96
            'no confidence'
          elsif z > -2.57
            '95% confidence'
          elsif z > -3.29
            '99% confidence'
          else
            '99.9% confidence'
          end
        else
          "No Change"
        end
      end
    end

    get '/' do
      @experiments = Split::Experiment.all
      erb :index
    end

    post '/:experiment' do
      @experiment = Split::Experiment.find(params[:experiment])
      @alternative = Split::Alternative.find(params[:alternative], params[:experiment])
      @experiment.winner = @alternative.name
      redirect url('/')
    end

    post '/reset/:experiment' do
      @experiment = Split::Experiment.find(params[:experiment])
      @experiment.reset
      redirect url('/')
    end

    delete '/:experiment' do
      @experiment = Split::Experiment.find(params[:experiment])
      @experiment.delete
      redirect url('/')
    end
  end
end