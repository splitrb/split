require 'spec_helper'
require 'split/experiment_catalog'
require 'split/experiment'
require 'split/user'

describe Split::User do
  let(:user_keys) { { 'link_color' => 'blue' } }
  let(:context) { double(:session => { split:  user_keys }) }
  let(:experiment) { Split::Experiment.new('link_color') }

  before(:each) do
    @subject = described_class.new(context)
  end

  it 'delegates methods correctly' do
    expect(@subject['link_color']).to eq(@subject.user['link_color'])
  end

  context '#cleanup_old_versions!' do
    let(:user_keys) { { 'link_color:1' => 'blue' } }

    it 'removes key if old experiment is found' do
      @subject.cleanup_old_versions!(experiment)
      expect(@subject.keys).to be_empty
    end
  end 

  context '#cleanup_old_experiments!' do
    let(:user_keys) { { 'link_color' => 'blue', 'link_color:finished' => true, 'link_color:time_of_assignment' => Time.now.to_s } }

    it 'removes keys if experiment is not found' do
      @subject.cleanup_old_experiments!
      
      expect(@subject.keys).to be_empty
    end

    it 'removes keys if experiment has a winner' do
      allow(Split::ExperimentCatalog).to receive(:find).with('link_color').and_return(experiment)
      allow(experiment).to receive(:has_winner?).and_return(true)
      allow(experiment).to receive(:start_time).and_return(Date.today)
      
      @subject.cleanup_old_experiments!
      
      expect(@subject.keys).to be_empty
    end

    it 'removes keys if experiment has not started yet' do
      allow(Split::ExperimentCatalog).to receive(:find).with('link_color').and_return(experiment)
      allow(experiment).to receive(:has_winner?).and_return(false)
      allow(experiment).to receive(:start_time).and_return(nil)
      
      @subject.cleanup_old_experiments!
      
      expect(@subject.keys).to be_empty
    end

    it 'keeps keys if the experiment has no winner and has started' do
      allow(Split::ExperimentCatalog).to receive(:find).with('link_color').and_return(experiment)
      allow(experiment).to receive(:has_winner?).and_return(false)
      allow(experiment).to receive(:start_time).and_return(Date.today)
      
      @subject.cleanup_old_experiments!
      
      expect(@subject.keys).to include("link_color")
      expect(@subject.keys).to include("link_color:finished")
      expect(@subject.keys).to include("link_color:time_of_assignment")
    end

    context 'when already cleaned up' do
      before do
        @subject.cleanup_old_experiments!
      end

      it 'does not clean up again' do
        expect(@subject).to_not receive(:keys_without_finished_and_time_of_assignment)
        @subject.cleanup_old_experiments!
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
