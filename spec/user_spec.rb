# frozen_string_literal: true

require "spec_helper"
require "split/experiment_catalog"
require "split/experiment"
require "split/user"

describe Split::User do
  let(:user_keys) { { "link_color" => "blue" } }
  let(:context) { double(session: { split:  user_keys }) }
  let(:experiment) { Split::Experiment.new("link_color") }

  before(:each) do
    @subject = described_class.new(context)
  end

  it "delegates methods correctly" do
    expect(@subject["link_color"]).to eq(@subject.user["link_color"])
  end

  context "#cleanup_old_versions!" do
    context "when there are multiple variations" do
      let(:experiment_version) { "#{experiment.name}:1" }
      let(:second_experiment_version) { "#{experiment.name}_another:1" }
      let(:third_experiment_version) { "variation_of_#{experiment.name}:1" }
      let(:user_keys) do
        {
          experiment_version => "blue",
          second_experiment_version => "red",
          third_experiment_version => "yellow"
        }
      end

      before(:each) { @subject.cleanup_old_versions!(experiment) }

      it "removes key if old experiment is found" do
        expect(@subject.keys).not_to include(experiment_version)
      end

      it "does not remove other keys" do
        expect(@subject.keys).to include(second_experiment_version, third_experiment_version)
      end
    end

    context 'current version does not have number' do
      describe 'when the user is in the experiment with old version number' do
        let(:user_keys) { { 'link_color:1' => 'blue', 'link_color:1:finished' => 'true' } }

        it 'removes all the old version keys' do
          @subject.cleanup_old_versions!(experiment)
          expect(@subject.keys).to be_empty
        end
      end

      describe 'when the user is in the experiment with current version' do
        let(:user_keys) { { 'link_color' => 'blue', 'link_color:finished' => 'true' } }

        it 'all the keys are reserved' do
          @subject.cleanup_old_versions!(experiment)
          expect(@subject.keys.size).to be(2)
        end
      end

      describe 'when the user is in another experiment without version number' do
        let(:user_keys) { { 'link' => 'a:b', 'link:finished' => 'true' } }

        it 'all the keys are reserved' do
          @subject.cleanup_old_versions!(experiment)
          expect(@subject.keys.size).to be(2)
        end
      end

      describe 'when the user is in another experiment with version number' do
        let(:user_keys) { { 'link:1' => 'a:b', 'link:1:finished' => 'true' } }

        it 'all the keys are reserved' do
          @subject.cleanup_old_versions!(experiment)
          expect(@subject.keys.size).to be(2)
        end
      end

      describe 'when the user is in another experiment having the current experiment name as substring' do
        let(:user_keys) { { 'link_color2' => 'blue', 'link_color2:finished' => 'true' } }

        it 'all the keys are reserved' do
          @subject.cleanup_old_versions!(experiment)
          expect(@subject.keys.size).to be(2)
        end
      end

      describe 'when the user is another experiment with version, having the current experiment name as substring ' do
        let(:user_keys) { { 'link_color2:1' => 'blue', 'link_color2:1:finished' => 'true' } }

        it 'all the keys are reserved' do
          @subject.cleanup_old_versions!(experiment)
          expect(@subject.keys.size).to be(2)
        end
      end
    end

    context 'current version has number' do
      before do
        experiment.reset
        experiment.reset
      end

      describe 'when the user is in the experiment without version number' do
        let(:user_keys) { { 'link_color' => 'blue', 'link_color:finished' => 'true' } }

        it 'removes all the old version keys' do
          @subject.cleanup_old_versions!(experiment)
          expect(@subject.keys).to be_empty
        end
      end

      describe 'when the user is in the experiment with an old version number' do
        let(:user_keys) { { 'link_color:1' => 'blue', 'link_color:1:finished' => 'true' } }

        it 'removes all the old version keys' do
          @subject.cleanup_old_versions!(experiment)
          expect(@subject.keys).to be_empty
        end
      end

      describe 'when the user is in the experiment with current version number' do
        let(:user_keys) { { 'link_color:2' => 'blue', 'link_color:2:finished' => 'true' } }

        it 'all the keys are reserved' do
          @subject.cleanup_old_versions!(experiment)
          expect(@subject.keys.size).to be(2)
        end
      end

      describe 'when the user is in another experiment, having the current experiment name as substring' do
        let(:user_keys) { { 'link_color2' => 'blue', 'link_color2:finished' => 'true' } }

        it 'all the keys are reserved' do
          @subject.cleanup_old_versions!(experiment)
          expect(@subject.keys.size).to be(2)
        end
      end

      describe 'when the user is in another experiment with version, having the current experiment name as substring' do
        let(:user_keys) { { 'link_color2:2' => 'blue', 'link_color2:2:finished' => 'true' } }

        it 'all the keys are reserved' do
          @subject.cleanup_old_versions!(experiment)
          expect(@subject.keys.size).to be(2)
        end
      end
    end
  end

  context "#cleanup_old_experiments!" do
    let(:user_keys) do
      {
        'link_color' => 'blue',
        'link_color:finished' => true,
        'link_color:time_of_assignment' => Time.now.to_s,
      }
    end

    it "removes key if experiment is not found" do
      @subject.cleanup_old_experiments!

      expect(@subject.keys).to be_empty
    end

    it "removes key if experiment has a winner" do
      allow(Split::ExperimentCatalog).to receive(:find).with("link_color").and_return(experiment)
      allow(experiment).to receive(:start_time).and_return(Date.today)
      allow(experiment).to receive(:has_winner?).and_return(true)
      @subject.cleanup_old_experiments!
      expect(@subject.keys).to be_empty
    end

    it "removes key if experiment has not started yet" do
      allow(Split::ExperimentCatalog).to receive(:find).with("link_color").and_return(experiment)
      allow(experiment).to receive(:has_winner?).and_return(false)
      allow(experiment).to receive(:start_time).and_return(nil)
      @subject.cleanup_old_experiments!
      expect(@subject.keys).to be_empty
    end

    it "keeps keys if the experiment has no winner and has started" do
      allow(Split::ExperimentCatalog).to receive(:find).with('link_color').and_return(experiment)
      allow(experiment).to receive(:has_winner?).and_return(false)
      allow(experiment).to receive(:start_time).and_return(Date.today)
      @subject.cleanup_old_experiments!
      expect(@subject.keys).to include("link_color")
      expect(@subject.keys).to include("link_color:finished")
      expect(@subject.keys).to include("link_color:time_of_assignment")
    end

    describe "when the user is in the experiment with version number" do
      let(:user_keys) do
        {
          'link_color:1' => 'blue',
          'link_color:1:finished' => true,
          'link_color:1:time_of_assignment' => Time.now.to_s,
        }
      end

      it "keeps keys when the experiment has no winner and has started" do
        allow(Split::ExperimentCatalog).to receive(:find).with('link_color').and_return(experiment)
        allow(experiment).to receive(:has_winner?).and_return(false)
        allow(experiment).to receive(:start_time).and_return(Date.today)
        @subject.cleanup_old_experiments!
        expect(@subject.keys).to include("link_color:1")
        expect(@subject.keys).to include("link_color:1:finished")
        expect(@subject.keys).to include("link_color:1:time_of_assignment")
      end
    end

    context "with finished key" do
      let(:user_keys) { { "link_color" => "blue", "link_color:finished" => true } }

      it "does not remove finished key for experiment without a winner" do
        allow(Split::ExperimentCatalog).to receive(:find).with("link_color").and_return(experiment)
        allow(Split::ExperimentCatalog).to receive(:find).with("link_color:finished").and_return(nil)
        allow(experiment).to receive(:start_time).and_return(Date.today)
        allow(experiment).to receive(:has_winner?).and_return(false)
        @subject.cleanup_old_experiments!
        expect(@subject.keys).to include("link_color")
        expect(@subject.keys).to include("link_color:finished")
      end
    end

    context "when already cleaned up" do
      before do
        @subject.cleanup_old_experiments!
      end

      it "does not clean up again" do
        expect(@subject).to_not receive(:keys_without_finished)
        @subject.cleanup_old_experiments!
      end
    end
  end

  context "#max_experiments_reached?" do
    context "when multiple experiments are not allowed" do
      before do
        Split.configuration.allow_multiple_experiments = false
      end

      context "when user is not in any experiment" do
        let(:user_keys) { { } }

        it "max not reached when checking against same experiment" do
          expect(@subject.max_experiments_reached?("link_color")).to be_falsey
        end
      end

      context "when user is already in an experiment" do
        let(:user_keys) do
          {
            'link_color' => 'blue',
            'link_color:finished' => true,
            'link_color:time_of_assignment' => Time.now.to_s,
            'link_color:eligibility' => "ELIGIBLE",
          }
        end

        it "max reached when checking against another experiment" do
          expect(@subject.max_experiments_reached?("link")).to be_truthy
        end

        it "max reached when checking against another experiment contain current experiment as substring" do
          expect(@subject.max_experiments_reached?("link_color_v2")).to be_truthy
        end
      end

      context "when user is already in an experiment with version number" do
        let(:user_keys) do
          {
            'link_color:1' => 'blue',
            'link_color:1:finished' => true,
            'link_color:1:time_of_assignment' => Time.now.to_s,
            'link_color:1:eligibility' => "ELIGIBLE",
          }
        end

        it "max reached when checking against another experiment" do
          expect(@subject.max_experiments_reached?("link")).to be_truthy
        end

        it "max reached when checking against another experiment but same version" do
          expect(@subject.max_experiments_reached?("link:2")).to be_truthy
        end

        it "max reached when checking against another experiment contain current experiment as substring" do
          expect(@subject.max_experiments_reached?("link_color_v2")).to be_truthy
        end

        it "max reached when checking against another experiment contain current experiment as substring, but same version" do
          expect(@subject.max_experiments_reached?("link_color_v2:2")).to be_truthy
        end
      end
    end

    context "when multiple experiments with control are allowed" do
      let(:alternatives) { [ "control", "blue" ] }
      let(:experiment2) { Split::Experiment.new('link_shape') }

      before do
        Split.configuration.allow_multiple_experiments = "control"
        Split::ExperimentCatalog.find_or_create("link_color", alternatives)
        Split::ExperimentCatalog.find_or_create("link_shape", alternatives)
      end

      context "user is not in any experiments" do
        let(:user_keys) { { } }

        it "max not reached for experiment" do
          expect(@subject.max_experiments_reached?("link_color")).to be_falsey
        end

        it "max not reached for experiment with a version" do
          expect(@subject.max_experiments_reached?("link_color:2")).to be_falsey
        end
      end

      context "user is in control with experiment2" do
        let(:user_keys) do
          {
            'link_shape' => 'control',
            'link_shape:finished' => true,
            'link_shape:time_of_assignment' => Time.now.to_s,
            'link_shape:eligibility' => "ELIGIBLE",
          }
        end

        it "max not reached for a different experiment" do
          expect(@subject.max_experiments_reached?("link_color")).to be_falsey
        end
      end

      context "user is in alternative with experiment1, control with experiment2" do
        let(:user_keys) do
          {
            'link_color' => 'blue',
            'link_color:finished' => true,
            'link_color:time_of_assignment' => Time.now.to_s,
            'link_color:eligibility' => "ELIGIBLE",
            'link_shape' => 'control',
            'link_shape:finished' => true,
            'link_shape:time_of_assignment' => Time.now.to_s,
            'link_shape:eligibility' => "ELIGIBLE",
          }
        end

        it "max reached for other experiments" do
          expect(@subject.max_experiments_reached?("link_font")).to be_truthy
        end
      end
    end

    context "when multiple experiments are allowed" do
      let(:alternatives) { [ "control", "blue" ] }
      let(:experiment2) { Split::Experiment.new('link_shape') }
      let(:user_keys) do
        {
          'link_color' => 'blue',
          'link_color:finished' => true,
          'link_color:time_of_assignment' => Time.now.to_s,
          'link_color:eligibility' => "ELIGIBLE",
          'link_shape' => 'blue',
          'link_shape:finished' => true,
          'link_shape:time_of_assignment' => Time.now.to_s,
          'link_shape:eligibility' => "ELIGIBLE",
        }
      end

      before do
        Split.configuration.allow_multiple_experiments = "true"
        Split::ExperimentCatalog.find_or_create("link_color", alternatives)
        Split::ExperimentCatalog.find_or_create("link_shape", alternatives)
      end

      it "max not reached for other experiments" do
        expect(@subject.max_experiments_reached?("link_font")).to be_falsey
      end
    end
  end

  context "#active_experiments" do
    context "when the experiment has no version number" do
      let(:user_keys) do
        {
          'link_color' => 'blue',
          'link_color:finished' => true,
          'link_color:time_of_assignment' => Time.now.to_s,
          'link_color:eligibility' => "ELIGIBLE",
        }
      end

      context "when the experiment no longer exists" do
        it "doesn't include the experiment" do
          expect(@subject.active_experiments).to be_empty
        end
      end

      context "when the experiment exists" do
        before do
          allow(Split::ExperimentCatalog).to receive(:find).with('link_color').and_return(experiment)
        end

        it "only includes the experiment when there is no winner" do
          allow(experiment).to receive(:has_winner?).and_return(false)

          expect(@subject.active_experiments).to eq({'link_color' => 'blue'})
        end

        it "doesn't include the experiment when there is a winner" do
          allow(experiment).to receive(:has_winner?).and_return(true)

          expect(@subject.active_experiments).to be_empty
        end
      end
    end

    context "when the experiment has a version number" do
      let(:user_keys) do
        {
          'link_color:1' => 'blue',
          'link_color:1:finished' => true,
          'link_color:1:time_of_assignment' => Time.now.to_s,
          'link_color:1:eligibility' => "ELIGIBLE",
        }
      end
      before do
        experiment.reset
      end

      context "when the experiment no longer exists" do
        it "doesn't include the experiment" do
          expect(@subject.active_experiments).to be_empty
        end
      end

      context "when the experiment exists" do
        before do
          allow(Split::ExperimentCatalog).to receive(:find).with('link_color').and_return(experiment)
        end

        it "only includes the experiment when there is no winner" do
          allow(experiment).to receive(:has_winner?).and_return(false)

          expect(@subject.active_experiments).to eq({'link_color' => 'blue'})
        end

        it "doesn't include the experiment when there is a winner" do
          allow(experiment).to receive(:has_winner?).and_return(true)

          expect(@subject.active_experiments).to be_empty
        end
      end
    end
  end

  context "#alternative_key_for_experiment" do
    context "if there is only 1 version of the experiment" do
      it "returns the current experiment key" do
        expect(@subject.alternative_key_for_experiment(experiment)).to eq("link_color")
      end
    end

    context "if there are multiple versions of the experiment" do
      before { 2.times { experiment.increment_version } }

      context "user has a key from a first version of the experiment" do
        let(:user_keys) { { "link_color" => "blue" } }

        it "returns the current experiment key" do
          expect(@subject.alternative_key_for_experiment(experiment)).to eq("link_color")
        end
      end

      context "user has a key from a previous version of the experiment" do
        let(:user_keys) { { "link_color:1" => "blue" } }

        it "returns the current experiment key" do
          expect(@subject.alternative_key_for_experiment(experiment)).to eq("link_color:1")
        end
      end

      context "user has the same key as the current version of the experiment" do 
        let(:user_keys) { { "link_color:2" => "blue" } }

        it "returns the current experiment key" do
          expect(@subject.alternative_key_for_experiment(experiment)).to eq("link_color:2")
        end
      end

      context "user does not have any key for the experiment" do 
        let(:user_keys) { { } }

        it "returns the current experiment key" do
          expect(@subject.alternative_key_for_experiment(experiment)).to eq("link_color:2")
        end
      end
    end
  end

  context "allows user to be loaded from adapter" do
    it "loads user from adapter (RedisAdapter)" do
      user = Split::Persistence::RedisAdapter.new(nil, 112233)
      user["foo"] = "bar"

      ab_user = Split::User.find(112233, :redis)

      expect(ab_user["foo"]).to eql("bar")
    end

    it "returns nil if adapter does not implement a finder method" do
      ab_user = Split::User.find(112233, :dual_adapter)
      expect(ab_user).to be_nil
    end
  end

  context "instantiated with custom adapter" do
    let(:custom_adapter) { double(:persistence_adapter) }

    before do
      @subject = described_class.new(context, custom_adapter)
    end

    it "sets user to the custom adapter" do
      expect(@subject.user).to eq(custom_adapter)
    end
  end
end
