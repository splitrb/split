require 'spec_helper'

# TODO change some of these tests to use Rack::Test

describe Split::Helper do
  include Split::Helper

  let(:experiment) {
    Split::ExperimentCatalog.find_or_create('link_color', 'blue', 'red')
  }

  describe "ab_test" do
    it "should not raise an error when passed strings for alternatives" do
      expect(lambda { ab_test('xyz', '1', '2', '3') }).not_to raise_error
    end

    it "should not raise an error when passed an array for alternatives" do
      expect(lambda { ab_test('xyz', ['1', '2', '3']) }).not_to raise_error
    end

    it "should raise the appropriate error when passed integers for alternatives" do
      expect(lambda { ab_test('xyz', 1, 2, 3) }).to raise_error
    end

    it "should raise the appropriate error when passed symbols for alternatives" do
      expect(lambda { ab_test('xyz', :a, :b, :c) }).to raise_error
    end

    it "should not raise error when passed an array for goals" do
      expect(lambda { ab_test({'link_color' => ["purchase", "refund"]}, 'blue', 'red') }).not_to raise_error
    end

    it "should not raise error when passed just one goal" do
      expect(lambda { ab_test({'link_color' => "purchase"}, 'blue', 'red') }).not_to raise_error
    end

    it "should assign a random alternative to a new user when there are an equal number of alternatives assigned" do
      ab_test('link_color', 'blue', 'red')
      expect(['red', 'blue']).to include(ab_user['link_color'])
    end

    it "should increment the participation counter after assignment to a new user" do
      previous_red_count = Split::Alternative.new('red', 'link_color').participant_count
      previous_blue_count = Split::Alternative.new('blue', 'link_color').participant_count

      ab_test('link_color', 'blue', 'red')

      new_red_count = Split::Alternative.new('red', 'link_color').participant_count
      new_blue_count = Split::Alternative.new('blue', 'link_color').participant_count

      expect((new_red_count + new_blue_count)).to eq(previous_red_count + previous_blue_count + 1)
    end

    it 'should not increment the counter for an experiment that the user is not participating in' do
      ab_test('link_color', 'blue', 'red')
      e = Split::ExperimentCatalog.find_or_create('button_size', 'small', 'big')
      expect(lambda {
        # User shouldn't participate in this second experiment
        ab_test('button_size', 'small', 'big')
      }).not_to change { e.participant_count }
    end

    it 'should not increment the counter for an ended experiment' do
      e = Split::ExperimentCatalog.find_or_create('button_size', 'small', 'big')
      e.winner = 'small'
      expect(lambda {
        a = ab_test('button_size', 'small', 'big')
        expect(a).to eq('small')
      }).not_to change { e.participant_count }
    end

    it 'should not increment the counter for an not started experiment' do
      expect(Split.configuration).to receive(:start_manually).and_return(true)
      e = Split::ExperimentCatalog.find_or_create('button_size', 'small', 'big')
      expect(lambda {
        a = ab_test('button_size', 'small', 'big')
        expect(a).to eq('small')
      }).not_to change { e.participant_count }
    end

    it "should return the given alternative for an existing user" do
      expect(ab_test('link_color', 'blue', 'red')).to eq ab_test('link_color', 'blue', 'red')
    end

    it 'should always return the winner if one is present' do
      experiment.winner = "orange"

      expect(ab_test('link_color', 'blue', 'red')).to eq('orange')
    end

    it "should allow the alternative to be force by passing it in the params" do
      @params = {'link_color' => 'blue'}
      alternative = ab_test('link_color', 'blue', 'red')
      expect(alternative).to eq('blue')
      alternative = ab_test('link_color', {'blue' => 1}, 'red' => 5)
      expect(alternative).to eq('blue')
      @params = {'link_color' => 'red'}
      alternative = ab_test('link_color', 'blue', 'red')
      expect(alternative).to eq('red')
      alternative = ab_test('link_color', {'blue' => 5}, 'red' => 1)
      expect(alternative).to eq('red')
    end

    it "should not allow an arbitrary alternative" do
      @params = {'link_color' => 'pink'}
      alternative = ab_test('link_color', 'blue')
      expect(alternative).to eq('blue')
    end

    it "should not store the split when a param forced alternative" do
      @params = {'link_color' => 'blue'}
      expect(ab_user).not_to receive(:[]=)
      ab_test('link_color', 'blue', 'red')
    end

    it "SPLIT_DISABLE query parameter should also force the alternative (uses control)" do
      @params = {'SPLIT_DISABLE' => 'true'}
      alternative = ab_test('link_color', 'blue', 'red')
      expect(alternative).to eq('blue')
      alternative = ab_test('link_color', {'blue' => 1}, 'red' => 5)
      expect(alternative).to eq('blue')
      alternative = ab_test('link_color', 'red', 'blue')
      expect(alternative).to eq('red')
      alternative = ab_test('link_color', {'red' => 5}, 'blue' => 1)
      expect(alternative).to eq('red')
    end

    it "should not store the split when Split generically disabled" do
      @params = {'SPLIT_DISABLE' => 'true'}
      expect(ab_user).not_to receive(:[]=)
      ab_test('link_color', 'blue', 'red')
    end

    context "when store_override is set" do
      before { Split.configuration.store_override = true }

      it "should store the forced alternative" do
        @params = {'link_color' => 'blue'}
        expect(ab_user).to receive(:[]=).with('link_color', 'blue')
        ab_test('link_color', 'blue', 'red')
      end
    end

    context "when on_trial_choose is set" do
      before { Split.configuration.on_trial_choose = :some_method }
      it "should call the method" do
        expect(self).to receive(:some_method)
        ab_test('link_color', 'blue', 'red')
      end
    end

    it "should allow passing a block" do
      alt = ab_test('link_color', 'blue', 'red')
      ret = ab_test('link_color', 'blue', 'red') { |alternative| "shared/#{alternative}" }
      expect(ret).to eq("shared/#{alt}")
    end

    it "should allow the share of visitors see an alternative to be specified" do
      ab_test('link_color', {'blue' => 0.8}, {'red' => 20})
      expect(['red', 'blue']).to include(ab_user['link_color'])
    end

    it "should allow alternative weighting interface as a single hash" do
      ab_test('link_color', {'blue' => 0.01}, 'red' => 0.2)
      experiment = Split::ExperimentCatalog.find('link_color')
      expect(experiment.alternatives.map(&:name)).to eq(['blue', 'red'])
      # TODO: persist alternative weights
      # expect(experiment.alternatives.collect{|a| a.weight}).to eq([0.01, 0.2])
    end

    it "should only let a user participate in one experiment at a time" do
      link_color = ab_test('link_color', 'blue', 'red')
      ab_test('button_size', 'small', 'big')
      expect(ab_user).to eq({'link_color' => link_color})
      big = Split::Alternative.new('big', 'button_size')
      expect(big.participant_count).to eq(0)
      small = Split::Alternative.new('small', 'button_size')
      expect(small.participant_count).to eq(0)
    end

    it "should let a user participate in many experiment with allow_multiple_experiments option" do
      Split.configure do |config|
        config.allow_multiple_experiments = true
      end
      link_color = ab_test('link_color', 'blue', 'red')
      button_size = ab_test('button_size', 'small', 'big')
      expect(ab_user).to eq({'link_color' => link_color, 'button_size' => button_size})
      button_size_alt = Split::Alternative.new(button_size, 'button_size')
      expect(button_size_alt.participant_count).to eq(1)
    end

    it "should not over-write a finished key when an experiment is on a later version" do
      experiment.increment_version
      ab_user = { experiment.key => 'blue', experiment.finished_key => true }
      finshed_session = ab_user.dup
      ab_test('link_color', 'blue', 'red')
      expect(ab_user).to eq(finshed_session)
    end
  end

  describe 'metadata' do
    before do
      Split.configuration.experiments = {
        :my_experiment => {
          :alternatives => ["one", "two"],
          :resettable => false,
          :metadata => { 'one' => 'Meta1', 'two' => 'Meta2' }
        }
      }
    end

    it 'should be passed to helper block' do
      @params = {'my_experiment' => 'one'}
      expect(ab_test('my_experiment')).to eq 'one'
      expect(ab_test('my_experiment') do |alternative, meta|
        meta
      end).to eq('Meta1')
    end

    it 'should pass empty hash to helper block if library disabled' do
      Split.configure do |config|
        config.enabled = false
      end

      expect(ab_test('my_experiment')).to eq 'one'
      expect(ab_test('my_experiment') do |_, meta|
        meta
      end).to eq({})
    end
  end

  describe 'finished' do
    before(:each) do
      @experiment_name = 'link_color'
      @alternatives = ['blue', 'red']
      @experiment = Split::ExperimentCatalog.find_or_create(@experiment_name, *@alternatives)
      @alternative_name = ab_test(@experiment_name, *@alternatives)
      @previous_completion_count = Split::Alternative.new(@alternative_name, @experiment_name).completed_count
    end

    it 'should increment the counter for the completed alternative' do
      finished(@experiment_name)
      new_completion_count = Split::Alternative.new(@alternative_name, @experiment_name).completed_count
      expect(new_completion_count).to eq(@previous_completion_count + 1)
    end

    it "should set experiment's finished key if reset is false" do
      finished(@experiment_name, {:reset => false})
      expect(ab_user).to eq(@experiment.key => @alternative_name, @experiment.finished_key => true)
    end

    it 'should not increment the counter if reset is false and the experiment has been already finished' do
      2.times { finished(@experiment_name, {:reset => false}) }
      new_completion_count = Split::Alternative.new(@alternative_name, @experiment_name).completed_count
      expect(new_completion_count).to eq(@previous_completion_count + 1)
    end

    it 'should not increment the counter for an experiment that the user is not participating in' do
      ab_test('button_size', 'small', 'big')

      # So, user should be participating in the link_color experiment and
      # receive the control for button_size. As the user is not participating in
      # the button size experiment, finishing it should not increase the
      # completion count for that alternative.
      expect(lambda {
        finished('button_size')
      }).not_to change { Split::Alternative.new('small', 'button_size').completed_count }
    end

    it 'should not increment the counter for an ended experiment' do
      e = Split::ExperimentCatalog.find_or_create('button_size', 'small', 'big')
      e.winner = 'small'
      a = ab_test('button_size', 'small', 'big')
      expect(a).to eq('small')
      expect(lambda {
        finished('button_size')
      }).not_to change { Split::Alternative.new(a, 'button_size').completed_count }
    end

    it "should clear out the user's participation from their session" do
      expect(ab_user).to eq(@experiment.key => @alternative_name)
      finished(@experiment_name)
      expect(ab_user).to eq({})
    end

    it "should not clear out the users session if reset is false" do
      expect(ab_user).to eq(@experiment.key => @alternative_name)
      finished(@experiment_name, {:reset => false})
      expect(ab_user).to eq(@experiment.key => @alternative_name, @experiment.finished_key => true)
    end

    it "should reset the users session when experiment is not versioned" do
      expect(ab_user).to eq(@experiment.key => @alternative_name)
      finished(@experiment_name)
      expect(ab_user).to eq({})
    end

    it "should reset the users session when experiment is versioned" do
      @experiment.increment_version
      @alternative_name = ab_test(@experiment_name, *@alternatives)

      expect(ab_user).to eq(@experiment.key => @alternative_name)
      finished(@experiment_name)
      expect(ab_user).to eq({})
    end

    it "should do nothing where the experiment was not started by this user" do
      ab_user = nil
      expect(lambda { finished('some_experiment_not_started_by_the_user') }).not_to raise_exception
    end

    context "when on_trial_complete is set" do
      before { Split.configuration.on_trial_complete = :some_method }
      it "should call the method" do
        expect(self).to receive(:some_method)
        finished(@experiment_name)
      end

      it "should not call the method without alternative" do
        ab_user[@experiment.key] = nil
        expect(self).not_to receive(:some_method)
        finished(@experiment_name)
      end
    end
  end

  context "finished with config" do
    it "passes reset option" do
      Split.configuration.experiments = {
        :my_experiment => {
          :alternatives => ["one", "two"],
          :resettable => false,
        }
      }
      alternative = ab_test(:my_experiment)
      experiment = Split::ExperimentCatalog.find :my_experiment

      finished :my_experiment
      expect(ab_user).to eq(experiment.key => alternative, experiment.finished_key => true)
    end
  end

  context "finished with metric name" do
    before { Split.configuration.experiments = {} }
    before { expect(Split::Alternative).to receive(:new).at_least(1).times.and_call_original }

    def should_finish_experiment(experiment_name, should_finish=true)
      alts = Split.configuration.experiments[experiment_name][:alternatives]
      experiment = Split::ExperimentCatalog.find_or_create(experiment_name, *alts)
      alt_name = ab_user[experiment.key] = alts.first
      alt = double('alternative')
      expect(alt).to receive(:name).at_most(1).times.and_return(alt_name)
      expect(Split::Alternative).to receive(:new).at_most(1).times.with(alt_name, experiment_name.to_s).and_return(alt)
      if should_finish
        expect(alt).to receive(:increment_completion).at_most(1).times
      else
        expect(alt).not_to receive(:increment_completion)
      end
    end

    it "completes the test" do
      Split.configuration.experiments[:my_experiment] = {
        :alternatives => [ "control_opt", "other_opt" ],
        :metric => :my_metric
      }
      should_finish_experiment :my_experiment
      finished :my_metric
    end

    it "completes all relevant tests" do
      Split.configuration.experiments = {
        :exp_1 => {
          :alternatives => [ "1-1", "1-2" ],
          :metric => :my_metric
        },
        :exp_2 => {
          :alternatives => [ "2-1", "2-2" ],
          :metric => :another_metric
        },
        :exp_3 => {
          :alternatives => [ "3-1", "3-2" ],
          :metric => :my_metric
        },
      }
      should_finish_experiment :exp_1
      should_finish_experiment :exp_2, false
      should_finish_experiment :exp_3
      finished :my_metric
    end

    it "passes reset option" do
      Split.configuration.experiments = {
        :my_exp => {
          :alternatives => ["one", "two"],
          :metric => :my_metric,
          :resettable => false,
        }
      }
      alternative_name = ab_test(:my_exp)
      exp = Split::ExperimentCatalog.find :my_exp

      finished :my_metric
      expect(ab_user[exp.key]).to eq(alternative_name)
      expect(ab_user[exp.finished_key]).to be_truthy
    end

    it "passes through options" do
      Split.configuration.experiments = {
        :my_exp => {
          :alternatives => ["one", "two"],
          :metric => :my_metric,
        }
      }
      alternative_name = ab_test(:my_exp)
      exp = Split::ExperimentCatalog.find :my_exp

      finished :my_metric, :reset => false
      expect(ab_user[exp.key]).to eq(alternative_name)
      expect(ab_user[exp.finished_key]).to be_truthy
    end
  end

  describe 'conversions' do
    it 'should return a conversion rate for an alternative' do
      alternative_name = ab_test('link_color', 'blue', 'red')

      previous_convertion_rate = Split::Alternative.new(alternative_name, 'link_color').conversion_rate
      expect(previous_convertion_rate).to eq(0.0)

      finished('link_color')

      new_convertion_rate = Split::Alternative.new(alternative_name, 'link_color').conversion_rate
      expect(new_convertion_rate).to eq(1.0)
    end
  end

  describe 'active experiments' do
    it 'should show an active test' do
      alternative = ab_test('def', '4', '5', '6')
      expect(active_experiments.count).to eq 1
      expect(active_experiments.first[0]).to eq "def"
      expect(active_experiments.first[1]).to eq alternative
    end

    it 'should show a finished test' do
      alternative = ab_test('def', '4', '5', '6')
      finished('def', {:reset => false})
      expect(active_experiments.count).to eq 1
      expect(active_experiments.first[0]).to eq "def"
      expect(active_experiments.first[1]).to eq alternative
    end

    it 'should show multiple tests' do
      Split.configure do |config|
        config.allow_multiple_experiments = true
      end
      alternative = ab_test('def', '4', '5', '6')
      another_alternative = ab_test('ghi', '7', '8', '9')
      expect(active_experiments.count).to eq 2
      expect(active_experiments['def']).to eq alternative
      expect(active_experiments['ghi']).to eq another_alternative
    end

    it 'should not show tests with winners' do
      Split.configure do |config|
        config.allow_multiple_experiments = true
      end
      e = Split::ExperimentCatalog.find_or_create('def', '4', '5', '6')
      e.winner = '4'
      alternative = ab_test('def', '4', '5', '6')
      another_alternative = ab_test('ghi', '7', '8', '9')
      expect(active_experiments.count).to eq 1
      expect(active_experiments.first[0]).to eq "ghi"
      expect(active_experiments.first[1]).to eq another_alternative
    end
  end

  describe 'when user is a robot' do
    before(:each) do
      @request = OpenStruct.new(:user_agent => 'Googlebot/2.1 (+http://www.google.com/bot.html)')
    end

    describe 'ab_test' do
      it 'should return the control' do
        alternative = ab_test('link_color', 'blue', 'red')
        expect(alternative).to eq experiment.control.name
      end

      it "should not increment the participation count" do

        previous_red_count = Split::Alternative.new('red', 'link_color').participant_count
        previous_blue_count = Split::Alternative.new('blue', 'link_color').participant_count

        ab_test('link_color', 'blue', 'red')

        new_red_count = Split::Alternative.new('red', 'link_color').participant_count
        new_blue_count = Split::Alternative.new('blue', 'link_color').participant_count

        expect((new_red_count + new_blue_count)).to eq(previous_red_count + previous_blue_count)
      end
    end

    describe 'finished' do
      it "should not increment the completed count" do
        alternative_name = ab_test('link_color', 'blue', 'red')

        previous_completion_count = Split::Alternative.new(alternative_name, 'link_color').completed_count

        finished('link_color')

        new_completion_count = Split::Alternative.new(alternative_name, 'link_color').completed_count

        expect(new_completion_count).to eq(previous_completion_count)
      end
    end
  end

  describe 'when providing custom ignore logic' do
    context "using a proc to configure custom logic" do

      before(:each) do
        Split.configure do |c|
          c.ignore_filter = proc{|request| true } # ignore everything
        end
      end

      it "ignores the ab_test" do
        ab_test('link_color', 'blue', 'red')

        red_count = Split::Alternative.new('red', 'link_color').participant_count
        blue_count = Split::Alternative.new('blue', 'link_color').participant_count
        expect((red_count + blue_count)).to be(0)
      end
    end
  end

  shared_examples_for "a disabled test" do
    describe 'ab_test' do
      it 'should return the control' do
        alternative = ab_test('link_color', 'blue', 'red')
        expect(alternative).to eq experiment.control.name
      end

      it "should not increment the participation count" do
        previous_red_count = Split::Alternative.new('red', 'link_color').participant_count
        previous_blue_count = Split::Alternative.new('blue', 'link_color').participant_count

        ab_test('link_color', 'blue', 'red')

        new_red_count = Split::Alternative.new('red', 'link_color').participant_count
        new_blue_count = Split::Alternative.new('blue', 'link_color').participant_count

        expect((new_red_count + new_blue_count)).to eq(previous_red_count + previous_blue_count)
      end
    end

    describe 'finished' do
      it "should not increment the completed count" do
        alternative_name = ab_test('link_color', 'blue', 'red')

        previous_completion_count = Split::Alternative.new(alternative_name, 'link_color').completed_count

        finished('link_color')

        new_completion_count = Split::Alternative.new(alternative_name, 'link_color').completed_count

        expect(new_completion_count).to eq(previous_completion_count)
      end
    end
  end

  describe 'when ip address is ignored' do
    context "individually" do
      before(:each) do
        @request = OpenStruct.new(:ip => '81.19.48.130')
        Split.configure do |c|
          c.ignore_ip_addresses << '81.19.48.130'
        end
      end

      it_behaves_like "a disabled test"
    end

    context "for a range" do
      before(:each) do
        @request = OpenStruct.new(:ip => '81.19.48.129')
        Split.configure do |c|
          c.ignore_ip_addresses << /81\.19\.48\.[0-9]+/
        end
      end

      it_behaves_like "a disabled test"
    end

    context "using both a range and a specific value" do
      before(:each) do
        @request = OpenStruct.new(:ip => '81.19.48.128')
        Split.configure do |c|
          c.ignore_ip_addresses << '81.19.48.130'
          c.ignore_ip_addresses << /81\.19\.48\.[0-9]+/
        end
      end

      it_behaves_like "a disabled test"
    end
  end

  describe 'versioned experiments' do
    it "should use version zero if no version is present" do
      alternative_name = ab_test('link_color', 'blue', 'red')
      expect(experiment.version).to eq(0)
      expect(ab_user).to eq({'link_color' => alternative_name})
    end

    it "should save the version of the experiment to the session" do
      experiment.reset
      expect(experiment.version).to eq(1)
      alternative_name = ab_test('link_color', 'blue', 'red')
      expect(ab_user).to eq({'link_color:1' => alternative_name})
    end

    it "should load the experiment even if the version is not 0" do
      experiment.reset
      expect(experiment.version).to eq(1)
      alternative_name = ab_test('link_color', 'blue', 'red')
      expect(ab_user).to eq({'link_color:1' => alternative_name})
      return_alternative_name = ab_test('link_color', 'blue', 'red')
      expect(return_alternative_name).to eq(alternative_name)
    end

    it "should reset the session of a user on an older version of the experiment" do
      alternative_name = ab_test('link_color', 'blue', 'red')
      expect(ab_user).to eq({'link_color' => alternative_name})
      alternative = Split::Alternative.new(alternative_name, 'link_color')
      expect(alternative.participant_count).to eq(1)

      experiment.reset
      expect(experiment.version).to eq(1)
      alternative = Split::Alternative.new(alternative_name, 'link_color')
      expect(alternative.participant_count).to eq(0)

      new_alternative_name = ab_test('link_color', 'blue', 'red')
      expect(ab_user['link_color:1']).to eq(new_alternative_name)
      new_alternative = Split::Alternative.new(new_alternative_name, 'link_color')
      expect(new_alternative.participant_count).to eq(1)
    end

    it "should cleanup old versions of experiments from the session" do
      alternative_name = ab_test('link_color', 'blue', 'red')
      expect(ab_user).to eq({'link_color' => alternative_name})
      alternative = Split::Alternative.new(alternative_name, 'link_color')
      expect(alternative.participant_count).to eq(1)

      experiment.reset
      expect(experiment.version).to eq(1)
      alternative = Split::Alternative.new(alternative_name, 'link_color')
      expect(alternative.participant_count).to eq(0)

      new_alternative_name = ab_test('link_color', 'blue', 'red')
      expect(ab_user).to eq({'link_color:1' => new_alternative_name})
    end

    it "should only count completion of users on the current version" do
      alternative_name = ab_test('link_color', 'blue', 'red')
      expect(ab_user).to eq({'link_color' => alternative_name})
      alternative = Split::Alternative.new(alternative_name, 'link_color')

      experiment.reset
      expect(experiment.version).to eq(1)

      finished('link_color')
      alternative = Split::Alternative.new(alternative_name, 'link_color')
      expect(alternative.completed_count).to eq(0)
    end
  end

  context 'when redis is not available' do
    before(:each) do
      expect(Split).to receive(:redis).at_most(5).times.and_raise(Errno::ECONNREFUSED.new)
    end

    context 'and db_failover config option is turned off' do
      before(:each) do
        Split.configure do |config|
          config.db_failover = false
        end
      end

      describe 'ab_test' do
        it 'should raise an exception' do
          expect(lambda { ab_test('link_color', 'blue', 'red') }).to raise_error
        end
      end

      describe 'finished' do
        it 'should raise an exception' do
          expect(lambda { finished('link_color') }).to raise_error
        end
      end

      describe "disable split testing" do
        before(:each) do
          Split.configure do |config|
            config.enabled = false
          end
        end

        it "should not attempt to connect to redis" do
          expect(lambda { ab_test('link_color', 'blue', 'red') }).not_to raise_error
        end

        it "should return control variable" do
          expect(ab_test('link_color', 'blue', 'red')).to eq('blue')
          expect(lambda { finished('link_color') }).not_to raise_error
        end
      end
    end

    context 'and db_failover config option is turned on' do
      before(:each) do
        Split.configure do |config|
          config.db_failover = true
        end
      end

      describe 'ab_test' do
        it 'should not raise an exception' do
          expect(lambda { ab_test('link_color', 'blue', 'red') }).not_to raise_error
        end

        it 'should call db_failover_on_db_error proc with error as parameter' do
          Split.configure do |config|
            config.db_failover_on_db_error = proc do |error|
              expect(error).to be_a(Errno::ECONNREFUSED)
            end
          end

          expect(Split.configuration.db_failover_on_db_error).to receive(:call)
          ab_test('link_color', 'blue', 'red')
        end

        it 'should always use first alternative' do
          expect(ab_test('link_color', 'blue', 'red')).to eq('blue')
          expect(ab_test('link_color', {'blue' => 0.01}, 'red' => 0.2)).to eq('blue')
          expect(ab_test('link_color', {'blue' => 0.8}, {'red' => 20})).to eq('blue')
          expect(ab_test('link_color', 'blue', 'red') do |alternative|
            "shared/#{alternative}"
          end).to eq('shared/blue')
        end

        context 'and db_failover_allow_parameter_override config option is turned on' do
          before(:each) do
            Split.configure do |config|
              config.db_failover_allow_parameter_override = true
            end
          end

          context 'and given an override parameter' do
            it 'should use given override instead of the first alternative' do
              @params = {'link_color' => 'red'}
              expect(ab_test('link_color', 'blue', 'red')).to eq('red')
              expect(ab_test('link_color', 'blue', 'red', 'green')).to eq('red')
              expect(ab_test('link_color', {'blue' => 0.01}, 'red' => 0.2)).to eq('red')
              expect(ab_test('link_color', {'blue' => 0.8}, {'red' => 20})).to eq('red')
              expect(ab_test('link_color', 'blue', 'red') do |alternative|
                "shared/#{alternative}"
              end).to eq('shared/red')
            end
          end
        end

        context 'and preloaded config given' do
          before do
            Split.configuration.experiments[:link_color] = {
              :alternatives => [ "blue", "red" ],
            }
          end

          it "uses first alternative" do
            expect(ab_test(:link_color)).to eq("blue")
          end
        end
      end

      describe 'finished' do
        it 'should not raise an exception' do
          expect(lambda { finished('link_color') }).not_to raise_error
        end

        it 'should call db_failover_on_db_error proc with error as parameter' do
          Split.configure do |config|
            config.db_failover_on_db_error = proc do |error|
              expect(error).to be_a(Errno::ECONNREFUSED)
            end
          end

          expect(Split.configuration.db_failover_on_db_error).to receive(:call)
          finished('link_color')
        end
      end
    end
  end

  context "with preloaded config" do
    before { Split.configuration.experiments = {}}

    it "pulls options from config file" do
      Split.configuration.experiments[:my_experiment] = {
        :alternatives => [ "control_opt", "other_opt" ],
        :goals => ["goal1", "goal2"]
      }
      ab_test :my_experiment
      expect(Split::Experiment.new(:my_experiment).alternatives.map(&:name)).to eq([ "control_opt", "other_opt" ])
      expect(Split::Experiment.new(:my_experiment).goals).to eq([ "goal1", "goal2" ])
    end

    it "can be called multiple times" do
      Split.configuration.experiments[:my_experiment] = {
        :alternatives => [ "control_opt", "other_opt" ],
        :goals => ["goal1", "goal2"]
      }
      5.times { ab_test :my_experiment }
      experiment = Split::Experiment.new(:my_experiment)
      expect(experiment.alternatives.map(&:name)).to eq([ "control_opt", "other_opt" ])
      expect(experiment.goals).to eq([ "goal1", "goal2" ])
      expect(experiment.participant_count).to eq(1)
    end

    it "accepts multiple goals" do
      Split.configuration.experiments[:my_experiment] = {
        :alternatives => [ "control_opt", "other_opt" ],
        :goals => [ "goal1", "goal2", "goal3" ]
      }
      ab_test :my_experiment
      experiment = Split::Experiment.new(:my_experiment)
      expect(experiment.goals).to eq([ "goal1", "goal2", "goal3" ])
    end

    it "allow specifying goals to be optional" do
      Split.configuration.experiments[:my_experiment] = {
        :alternatives => [ "control_opt", "other_opt" ]
      }
      experiment = Split::Experiment.new(:my_experiment)
      expect(experiment.goals).to eq([])
    end

    it "accepts multiple alternatives" do
      Split.configuration.experiments[:my_experiment] = {
        :alternatives => [ "control_opt", "second_opt", "third_opt" ],
      }
      ab_test :my_experiment
      experiment = Split::Experiment.new(:my_experiment)
      expect(experiment.alternatives.map(&:name)).to eq([ "control_opt", "second_opt", "third_opt" ])
    end

    it "accepts probability on alternatives" do
      Split.configuration.experiments[:my_experiment] = {
        :alternatives => [
          { :name => "control_opt", :percent => 67 },
          { :name => "second_opt", :percent => 10 },
          { :name => "third_opt", :percent => 23 },
        ],
      }
      ab_test :my_experiment
      experiment = Split::Experiment.new(:my_experiment)
      expect(experiment.alternatives.collect{|a| [a.name, a.weight]}).to eq([['control_opt', 0.67], ['second_opt', 0.1], ['third_opt', 0.23]])
    end

    it "accepts probability on some alternatives" do
      Split.configuration.experiments[:my_experiment] = {
        :alternatives => [
          { :name => "control_opt", :percent => 34 },
          "second_opt",
          { :name => "third_opt", :percent => 23 },
          "fourth_opt",
        ],
      }
      ab_test :my_experiment
      experiment = Split::Experiment.new(:my_experiment)
      names_and_weights = experiment.alternatives.collect{|a| [a.name, a.weight]}
      expect(names_and_weights).to eq([['control_opt', 0.34], ['second_opt', 0.215], ['third_opt', 0.23], ['fourth_opt', 0.215]])
      expect(names_and_weights.inject(0){|sum, nw| sum + nw[1]}).to eq(1.0)
    end

    it "allows name param without probability" do
      Split.configuration.experiments[:my_experiment] = {
        :alternatives => [
          { :name => "control_opt" },
          "second_opt",
          { :name => "third_opt", :percent => 64 },
        ],
      }
      ab_test :my_experiment
      experiment = Split::Experiment.new(:my_experiment)
      names_and_weights = experiment.alternatives.collect{|a| [a.name, a.weight]}
      expect(names_and_weights).to eq([['control_opt', 0.18], ['second_opt', 0.18], ['third_opt', 0.64]])
      expect(names_and_weights.inject(0){|sum, nw| sum + nw[1]}).to eq(1.0)
    end

    it "fails gracefully if config is missing experiment" do
      Split.configuration.experiments = { :other_experiment => { :foo => "Bar" } }
      expect(lambda { ab_test :my_experiment }).to raise_error
    end

    it "fails gracefully if config is missing" do
      expect(lambda { Split.configuration.experiments = nil }).to raise_error
    end

    it "fails gracefully if config is missing alternatives" do
      Split.configuration.experiments[:my_experiment] = { :foo => "Bar" }
      expect(lambda { ab_test :my_experiment }).to raise_error
    end
  end

  it 'should handle multiple experiments correctly' do
    experiment2 = Split::ExperimentCatalog.find_or_create('link_color2', 'blue', 'red')
    alternative_name = ab_test('link_color', 'blue', 'red')
    alternative_name2 = ab_test('link_color2', 'blue', 'red')
    finished('link_color2')

    experiment2.alternatives.each do |alt|
      expect(alt.unfinished_count).to eq(0)
    end
  end

  context "with goals" do
    before do
      @experiment = {'link_color' => ["purchase", "refund"]}
      @alternatives = ['blue', 'red']
      @experiment_name, @goals = normalize_metric(@experiment)
      @goal1 = @goals[0]
      @goal2 = @goals[1]
    end

    it "should normalize experiment" do
      expect(@experiment_name).to eq("link_color")
      expect(@goals).to eq(["purchase", "refund"])
    end

    describe "ab_test" do
      it "should allow experiment goals interface as a single hash" do
        ab_test(@experiment, *@alternatives)
        experiment = Split::ExperimentCatalog.find('link_color')
        expect(experiment.goals).to eq(['purchase', "refund"])
      end
    end

    describe "finished" do
      before do
        @alternative_name = ab_test(@experiment, *@alternatives)
      end

      it "should increment the counter for the specified-goal completed alternative" do
        expect(lambda {
          expect(lambda {
            finished({"link_color" => ["purchase"]})
          }).not_to change {
            Split::Alternative.new(@alternative_name, @experiment_name).completed_count(@goal2)
          }
        }).to change {
          Split::Alternative.new(@alternative_name, @experiment_name).completed_count(@goal1)
        }.by(1)
      end
    end
  end
end
