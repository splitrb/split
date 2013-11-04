require 'spec_helper'
require 'rack/test'
require 'split/dashboard'

describe Split::Dashboard do
  include Rack::Test::Methods

  def app
    @app ||= Split::Dashboard
  end

  def link(color)
    Split::Alternative.new(color, experiment.name)
  end

  let(:experiment) {
    Split::Experiment.find_or_create("link_color", "blue", "red")
  }

  let(:experiment_with_goals) {
    Split::Experiment.find_or_create({"link_color" => ["goal_1", "goal_2"]}, "blue", "red")
  }

  let(:red_link) { link("red") }
  let(:blue_link) { link("blue") }

  it "should respond to /" do
    get '/'
    last_response.should be_ok
  end

  context "start experiment manually" do
    before do
      Split.configuration.start_manually = true
    end

    context "experiment without goals" do
      it "should display a Start button" do
        experiment
        get '/'
        last_response.body.should include('Start')

        post "/start/#{experiment.name}"
        get '/'
        last_response.body.should include('Reset Data')
      end
    end

    context "with goals" do
      it "should display a Start button" do
        experiment_with_goals
        get '/'
        last_response.body.should include('Start')

        post "/start/#{experiment.name}"
        get '/'
        last_response.body.should include('Reset Data')
      end
    end
  end

  it "should reset an experiment" do
    red_link.participant_count = 5
    blue_link.participant_count = 7
    experiment.winner = 'blue'

    post "/reset/#{experiment.name}"

    last_response.should be_redirect

    new_red_count = red_link.participant_count
    new_blue_count = blue_link.participant_count

    new_blue_count.should eql(0)
    new_red_count.should eql(0)
    experiment.winner.should be_nil
  end

  it "should delete an experiment" do
    delete "/#{experiment.name}"
    last_response.should be_redirect
    Split::Experiment.find(experiment.name).should be_nil
  end

  it "should mark an alternative as the winner" do
    experiment.winner.should be_nil
    post "/#{experiment.name}", :alternative => 'red'

    last_response.should be_redirect
    experiment.winner.name.should eql('red')
  end

  it "should display the start date" do
    experiment_start_time = Time.parse('2011-07-07')
    Time.stub(:now => experiment_start_time)
    experiment

    get '/'

    last_response.body.should include('<small>2011-07-07</small>')
  end

  it "should handle experiments without a start date" do
    experiment_start_time = Time.parse('2011-07-07')
    Time.stub(:now => experiment_start_time)
    Split.redis.hdel(:experiment_start_times, experiment.name)

    get '/'

    last_response.body.should include('<small>Unknown</small>')
  end
end
