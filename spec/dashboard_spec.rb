require 'spec_helper'
require 'rack/test'
require 'split/dashboard'

describe Split::Dashboard do
  include Rack::Test::Methods

  let(:link_color) {
    Split::Experiment.find_or_create('link_color', 'blue', 'red')
  }

  def link(color)
    Split::Alternative.new(color, 'link_color')
  end

  let(:red_link) {
    link("red")
  }

  let(:blue_link) {
    link("blue")
  }

  def app
    @app ||= Split::Dashboard
  end

  it "should respond to /" do
    get '/'
    last_response.should be_ok
  end

  it "should reset an experiment" do
    experiment = link_color

    red_link.participant_count = 5
    blue_link.participant_count = 7
    experiment.winner = 'blue'

    post '/reset/link_color'

    last_response.should be_redirect

    new_red_count = red_link.participant_count
    new_blue_count = blue_link.participant_count

    new_blue_count.should eql(0)
    new_red_count.should eql(0)
    experiment.winner.should be_nil
  end

  it "should delete an experiment" do
    experiment = link_color
    delete '/link_color'
    last_response.should be_redirect
    Split::Experiment.find('link_color').should be_nil
  end

  it "should mark an alternative as the winner" do
    experiment = link_color
    experiment.winner.should be_nil

    post '/link_color', :alternative => 'red'

    last_response.should be_redirect
    experiment.winner.name.should eql('red')
  end

  it "should display the start date" do
    experiment_start_time = Time.parse('2011-07-07')
    Time.stub(:now => experiment_start_time)
    experiment = link_color

    get '/'

    last_response.body.should include('<small>2011-07-07</small>')
  end

  it "should handle experiments without a start date" do
    experiment_start_time = Time.parse('2011-07-07')
    Time.stub(:now => experiment_start_time)
    experiment = link_color

    Split.redis.hdel(:experiment_start_times, experiment.name)

    get '/'

    last_response.body.should include('<small>Unknown</small>')
  end
end