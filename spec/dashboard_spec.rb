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
    Split::ExperimentCatalog.find_or_create("link_color", "blue", "red")
  }

  let(:experiment_with_goals) {
    Split::ExperimentCatalog.find_or_create({"link_color" => ["goal_1", "goal_2"]}, "blue", "red")
  }

  let(:metric) {
    Split::Metric.find_or_create(name: 'testmetric', experiments: [experiment, experiment_with_goals])
  }

  let(:red_link) { link("red") }
  let(:blue_link) { link("blue") }

  it "should respond to /" do
    get '/'
    expect(last_response).to be_ok
  end

  context "start experiment manually" do
    before do
      Split.configuration.start_manually = true
    end

    context "experiment without goals" do
      it "should display a Start button" do
        experiment
        get '/'
        expect(last_response.body).to include('Start')

        post "/start/#{experiment.name}"
        get '/'
        expect(last_response.body).to include('Reset Data')
        expect(last_response.body).not_to include('Metrics:')
      end
    end

    context "experiment with metrics" do
      it "should display the names of associated metrics" do
        metric
        get '/'
        expect(last_response.body).to include('Metrics:testmetric')
      end
    end

    context "with goals" do
      it "should display a Start button" do
        experiment_with_goals
        get '/'
        expect(last_response.body).to include('Start')

        post "/start/#{experiment.name}"
        get '/'
        expect(last_response.body).to include('Reset Data')
      end
    end
  end

  describe "index page" do
    context "with winner" do
      before { experiment.winner = 'red' }

      it "displays `Reopen Experiment` button" do
        get '/'

        expect(last_response.body).to include('Reopen Experiment')
      end
    end

    context "without winner" do
      it "should not display `Reopen Experiment` button" do
        get '/'

        expect(last_response.body).to_not include('Reopen Experiment')
      end
    end
  end

  describe "reopen experiment" do
    before { experiment.winner = 'red' }

    it 'redirects' do
      post "/reopen/#{experiment.name}"

      expect(last_response).to be_redirect
    end

    it "removes winner" do
      post "/reopen/#{experiment.name}"

      expect(experiment).to_not have_winner
    end

    it "keeps existing stats" do
      red_link.participant_count = 5
      blue_link.participant_count = 7
      experiment.winner = 'blue'

      post "/reopen/#{experiment.name}"

      expect(red_link.participant_count).to eq(5)
      expect(blue_link.participant_count).to eq(7)
    end
  end

  it "should reset an experiment" do
    red_link.participant_count = 5
    blue_link.participant_count = 7
    experiment.winner = 'blue'

    post "/reset/#{experiment.name}"

    expect(last_response).to be_redirect

    new_red_count = red_link.participant_count
    new_blue_count = blue_link.participant_count

    expect(new_blue_count).to eq(0)
    expect(new_red_count).to eq(0)
    expect(experiment.winner).to be_nil
  end

  it "should delete an experiment" do
    delete "/#{experiment.name}"
    expect(last_response).to be_redirect
    expect(Split::ExperimentCatalog.find(experiment.name)).to be_nil
  end

  it "should mark an alternative as the winner" do
    expect(experiment.winner).to be_nil
    post "/#{experiment.name}", :alternative => 'red'

    expect(last_response).to be_redirect
    expect(experiment.winner.name).to eq('red')
  end

  it "should display the start date" do
    experiment_start_time = Time.parse('2011-07-07')
    expect(Time).to receive(:now).at_least(:once).and_return(experiment_start_time)
    experiment

    get '/'

    expect(last_response.body).to include('<small>2011-07-07</small>')
  end

  it "should handle experiments without a start date" do
    experiment_start_time = Time.parse('2011-07-07')
    expect(Time).to receive(:now).at_least(:once).and_return(experiment_start_time)

    Split.redis.hdel(:experiment_start_times, experiment.name)

    get '/'

    expect(last_response.body).to include('<small>Unknown</small>')
  end
end
