require 'spec_helper'
require 'rack/test'
require 'split/dashboard'

describe Split::Dashboard do
  include Rack::Test::Methods

  def app
    @app ||= Split::Dashboard
  end

  it "should respond to /" do
    get '/'
    last_response.should be_ok
  end

  it "should reset an experiment" do
    experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
    red = Split::Alternative.find('red', 'link_color').participant_count

    red = Split::Alternative.find('red', 'link_color')
    blue = Split::Alternative.find('blue', 'link_color')
    red.participant_count = 5
    red.save
    blue.participant_count = 6
    blue.save

    post '/reset/link_color'

    last_response.should be_redirect

    new_red_count = Split::Alternative.find('red', 'link_color').participant_count
    new_blue_count = Split::Alternative.find('blue', 'link_color').participant_count

    new_blue_count.should eql(0)
    new_red_count.should eql(0)
  end

  it "should mark an alternative as the winner" do
    experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
    experiment.winner.should be_nil

    post '/link_color', :alternative => 'red'

    last_response.should be_redirect
    experiment.winner.name.should eql('red')
  end
end