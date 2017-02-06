# frozen_string_literal: true
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

  before(:example) do
    Split.configuration.experiments = {
      link_color: {
        alternatives: [
          { name: 'blue', percent: 50 },
          { name: 'red', percent: 50 }
        ],
        goals: %w(goal_1 goal_2)
      }
    }
  end

  let(:experiment) do
    Split::ExperimentCatalog.find_or_create('link_color')
  end

  let(:experiment_with_goals) do
    Split::ExperimentCatalog.find_or_create('link_color')
  end

  let(:metric) do
    Split::Metric.find_or_create(name: 'testmetric', experiments: [experiment, experiment_with_goals])
  end

  let(:red_link) { link('red') }
  let(:blue_link) { link('blue') }

  it 'should respond to /' do
    get '/'
    expect(last_response).to be_ok
  end

  context 'start experiment manually' do
    before do
      Split.configuration.start_manually = true
    end

    context 'experiment without goals' do
      it 'should display a Start button' do
        experiment
        get "experiments/#{experiment.name}"
        expect(last_response.body).to include('Start')

        post "/start?experiment=#{experiment.name}"
        get "experiments/#{experiment.name}"
        expect(last_response.body).to include('Reset Data')
        expect(last_response.body).not_to include('Metrics:')
      end
    end

    context 'experiment with metrics' do
      it 'should display the names of associated metrics' do
        metric
        get "/experiments/#{experiment.name}"
        expect(last_response.body).to include('Metrics:testmetric')
      end
    end

    context 'with goals' do
      it 'should display a Start button' do
        experiment_with_goals
        get "/experiments/#{experiment.name}"
        expect(last_response.body).to include('Start')

        post "/start?experiment=#{experiment.name}"
        get "/experiments/#{experiment.name}"
        expect(last_response.body).to include('Reset Data')
      end
    end
  end

  describe 'force alternative' do
    let!(:user) do
      Split::User.new(@app, experiment.name => 'a')
    end

    before do
      allow(Split::User).to receive(:new).and_return(user)
    end

    it "should set current user's alternative" do
      post "/force_alternative?experiment=#{experiment.name}", alternative: 'b'
      expect(user[experiment.name]).to eq('b')
    end
  end

  describe 'index page' do
    context 'with winner' do
      before { experiment.winner = 'red' }

      it 'displays `Reopen Experiment` button' do
        get "/experiments/#{experiment.name}"
        expect(last_response.body).to include('Reopen Experiment')
      end
    end

    context 'without winner' do
      it 'should not display `Reopen Experiment` button' do
        get "/experiments/#{experiment.name}"

        expect(last_response.body).to_not include('Reopen Experiment')
      end
    end
  end

  describe 'reopen experiment' do
    before { experiment.winner = 'red' }

    it 'redirects' do
      post "/reopen?experiment=#{experiment.name}"

      expect(last_response).to be_redirect
    end

    it 'removes winner' do
      post "/reopen?experiment=#{experiment.name}"

      updated_experiment = Split::ExperimentCatalog.find experiment.name
      expect(updated_experiment).to_not have_winner
    end

    it 'keeps existing stats' do
      red_link.participant_count = 5
      blue_link.participant_count = 7
      experiment.winner = 'blue'

      post "/reopen?experiment=#{experiment.name}"

      expect(red_link.participant_count).to eq(5)
      expect(blue_link.participant_count).to eq(7)
    end
  end

  it 'should reset an experiment' do
    red_link.participant_count = 5
    blue_link.participant_count = 7
    experiment.winner = 'blue'

    post "/reset?experiment=#{experiment.name}"

    # hef 2 reload because of memoiza tion
    updated_experiment = Split::ExperimentCatalog.find(experiment.name)

    expect(last_response).to be_redirect

    new_red_count = red_link.participant_count
    new_blue_count = blue_link.participant_count

    expect(new_blue_count).to eq(0)
    expect(new_red_count).to eq(0)
    expect(updated_experiment.winner).to be_nil
  end

  it 'should delete an experiment' do
    delete "/experiment?experiment=#{experiment.name}"
    expect(last_response).to be_redirect
    expect(Split::ExperimentCatalog.find(experiment.name)).to be_nil
  end

  it 'should mark an alternative as the winner' do
    expect(experiment.winner).to be_nil
    post "/experiment?experiment=#{experiment.name}", alternative: 'red'

    # hef 2 reload because of memoization
    updated_experiment = Split::ExperimentCatalog.find(experiment.name)

    expect(last_response).to be_redirect
    expect(updated_experiment.winner.name).to eq('red')
  end

  it 'should display the start date' do
    experiment_start_time = Time.parse('2011-07-07')
    expect(Time).to receive(:now).at_least(:once).and_return(experiment_start_time)
    experiment

    get "/experiments/#{experiment.name}"

    expect(last_response.body).to include('<small>2011-07-07</small>')
  end

  it 'should handle experiments without a start date' do
    experiment_start_time = Time.parse('2011-07-07')
    expect(Time).to receive(:now).at_least(:once).and_return(experiment_start_time)

    Split.redis.hdel(:experiment_start_times, experiment.name)

    get "/experiments/#{experiment.name}"

    expect(last_response.body).to include('<small>Unknown</small>')
  end
end
