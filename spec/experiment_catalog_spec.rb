# frozen_string_literal: true
require 'spec_helper'

describe Split::ExperimentCatalog do
  subject { Split::ExperimentCatalog }

  before(:example) do
    Split.configuration.experiments = {
      xyz: {
        alternatives: %w(1 2 3)
      }
    }
  end

  describe '.find_or_create' do
    it 'should not raise an error when passed experiment_name' do
      expect { subject.find_or_create('xyz') }.not_to raise_error
    end

    it 'load an experiment' do
      expect(subject.find_or_create('xyz').control.to_s).to eq('1')
    end
  end

  describe '.find' do
    it 'should return an existing experiment' do
      experiment = Split::Experiment.new('basket_text', alternatives: %w(blue red green))
      experiment.save

      experiment = subject.find('basket_text')

      expect(experiment.name).to eq('basket_text')
    end

    it 'should return nil if experiment not exist' do
      expect(subject.find('non_existent_experiment')).to be_nil
    end
  end
end
