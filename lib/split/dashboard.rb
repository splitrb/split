require 'sinatra/base'
require 'split'
require 'bigdecimal'
require 'split/dashboard/helpers'

if RUBY_VERSION < "1.9"
  require 'fastercsv'
  FCSV = FasterCSV
else
  require 'csv'
  FCSV = CSV
end

module Split
  class Dashboard < Sinatra::Base
    dir = File.dirname(File.expand_path(__FILE__))

    set :views,  "#{dir}/dashboard/views"
    set :public_folder, "#{dir}/dashboard/public"
    set :static, true
    set :method_override, true

    helpers Split::DashboardHelpers

    get '/' do
      @experiments = Split::Experiment.all
      erb :index
    end

    post '/:experiment' do
      @experiment = Split::Experiment.find(params[:experiment])
      @alternative = Split::Alternative.new(params[:alternative], params[:experiment])
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

    get '/export' do
      content_type 'application/csv', :charset => "utf-8"
      attachment "split_experiment_results.csv"
      csv = FCSV.generate do |csv|
        csv << ['Experiment', 'Alternative', 'Participants', 'Completed', 'Conversion Rate', 'Z score', 'Control', 'Winner']
        Split::Experiment.all.each do |experiment|
          experiment.alternatives.each do |alternative|
            csv << [experiment.name,
                    alternative.name,
                    alternative.participant_count,
                    alternative.completed_count,
                    round(alternative.conversion_rate, 3),
                    round(alternative.z_score, 3),
                    alternative.control?,
                    alternative.to_s == experiment.winner.to_s]
          end
        end
      end
    end
  end
end