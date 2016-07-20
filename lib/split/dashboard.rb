require 'sinatra/base'
require 'split'
require 'bigdecimal'
require 'split/dashboard/helpers'
require 'json'

module Split
  class Dashboard < Sinatra::Base
    dir = File.dirname(File.expand_path(__FILE__))

    set :views,  "#{dir}/dashboard/views"
    set :public_folder, "#{dir}/dashboard/public"
    set :static, true
    set :method_override, true
    set :show_exceptions, true

    helpers Split::DashboardHelpers

    get '/' do
      # Display experiments without a winner at the top of the dashboard
      @experiments = Split::Experiment.all_active_first

      @metrics = Split::Metric.all

      # Display Rails Environment mode (or Rack version if not using Rails)
      if Object.const_defined?('Rails')
        @current_env = Rails.env.titlecase
      else
        @current_env = "Rack: #{Rack.version}"
      end
      erb :index
    end

    get '/:experiment' do
      @experiment = Split::Experiment.find(params[:experiment])
      @metrics = Split::Metric.all

      if Object.const_defined?('Rails')
        @current_env = Rails.env.titlecase
      else
        @current_env = "Rack: #{Rack.version}"
      end
      erb :experiment
    end

    get '/:experiment/:goal' do
      @experiment = Split::Experiment.find(params[:experiment])
      @goal = params[:goal]
      @metrics = Split::Metric.all

      if Object.const_defined?('Rails')
        @current_env = Rails.env.titlecase
      else
        @current_env = "Rack: #{Rack.version}"
      end
      erb :goal, :layout => false
    end

    post '/:experiment' do
      @experiment = Split::Experiment.find(params[:experiment])
      @alternative = Split::Alternative.new(params[:alternative], params[:experiment])
      @experiment.winner = @alternative.name
      redirect url('/')
    end

    post '/start/:experiment' do
      @experiment = Split::Experiment.find(params[:experiment])
      @experiment.start
      redirect url('/')
    end
    
    get '/export/:experiment/json' do
      content_type :json
      
      @experiment = Split::Experiment.find(params[:experiment])
      
      time_now = Time.now.utc
      attachment "#{@experiment.name}_v#{@experiment.version}_t#{time_now.strftime("%Y_%m_%d_%H_%M_%S")}UTC.json"
      
      result = {'experiment_name' => @experiment.name, 'version' => @experiment.version, 
                'exported_at' => time_now.strftime("%Y-%m-%d %H:%M:%SUTC"), 'wiki_url' => @experiment.wiki_url, 
                'start_time' => (@experiment.start_time ? @experiment.start_time.strftime('%Y-%m-%d') : 'Unknown'),
                'end_time' => (@experiment.end_time ? @experiment.end_time.strftime('%Y-%m-%d') : 'Unknown')}
      result['winner'] = @experiment.has_winner? ? @experiment.winner.name : ''
      goal_results = {}
      @experiment.goals.each do |goal|
        @experiment.alternatives.each do |alternative|
          res = {}
          res['alternative_name'] = alternative.name.humanize
          res['is_control'] = alternative.control?
          res['participant_count'] = alternative.participant_count
          res['completion_count'] = alternative.completed_count(goal)
          res['conversion_rate'] = number_to_percentage(alternative.conversion_rate(goal))
          if @experiment.control.conversion_rate(goal) > 0 && !alternative.control?
            res['conversation_rate_delta'] = (alternative.conversion_rate(goal)/@experiment.control.conversion_rate(goal))-1 
          end
          res['z-score'] = round(alternative.z_score(goal), 3)
          res['z-score_confidence_level'] = confidence_level(alternative.z_score(goal))
          res['probability'] = round(alternative.beta_probability_better_than_control(goal), 3)
          res['probability_confidence_level'] = probability_confidence(alternative.beta_probability_better_than_control(goal))
          if alternative.completed_value(goal) != "N/A"
            res['order'] = alternative.completed_value(goal)
            if @experiment.control.completed_value(goal) != "N/A" && @experiment.control.completed_value(goal) > 0 && !alternative.control? 
              res['order_delta'] = (alternative.completed_value(goal)/@experiment.control.completed_value(goal))-1
            end
            res['order_probability'] = round(alternative.log_normal_probability_better_than_control(goal), 3)
            res['order_probability_confidence_level'] = probability_confidence(alternative.log_normal_probability_better_than_control(goal))
          end
          if alternative.combined_value(goal) != "N/A"
            res['session'] = alternative.combined_value(goal)
            if @experiment.control.combined_value(goal) != "N/A" && @experiment.control.combined_value(goal) > 0 && !alternative.control?
              res['session_delta'] = (alternative.combined_value(goal)/@experiment.control.combined_value(goal))-1
            end
            res['session_probility'] = round(alternative.combined_probability_better_than_control(goal), 3)
            res['session_probility_fidence_level'] = probability_confidence(alternative.combined_probability_better_than_control(goal))
          end
          goal_results[goal] = [] if goal_results[goal].nil?
          goal_results[goal] << res
        end
      end
      result['goals'] = goal_results
      
      result.to_json
    end
    
    post '/wiki/:experiment' do
      @experiment = Split::Experiment.find(params[:experiment])
      @experiment.wiki_url = params[:wiki_url]
      redirect url('/')
    end

    post '/reset/:experiment' do
      @experiment = Split::Experiment.find(params[:experiment])
      @experiment.reset
      redirect url('/')
    end

    post '/reopen/:experiment' do
      @experiment = Split::Experiment.find(params[:experiment])
      @experiment.reset_winner
      redirect url('/')
    end

    delete '/:experiment' do
      @experiment = Split::Experiment.find(params[:experiment])
      @experiment.delete
      redirect url('/')
    end
  end
end
