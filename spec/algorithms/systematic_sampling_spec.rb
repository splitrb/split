# frozen_string_literal: true
require "spec_helper"

describe Split::Algorithms::SystematicSampling do
  # it "should return an alternative" do
  #   experiment = Split::ExperimentCatalog.find_or_create('link_color', {'blue' => 100}, {'red' => 0 })
  #   expect(Split::Algorithms::WeightedSample.choose_alternative(experiment).class).to eq(Split::Alternative)
  # end

  # it "should always return a heavily weighted option" do
  #   experiment = Split::ExperimentCatalog.find_or_create('link_color', {'blue' => 100}, {'red' => 0 })
  #   expect(Split::Algorithms::WeightedSample.choose_alternative(experiment).name).to eq('blue')
  # end

  context "for a valid experiment" do
    let!(:valid_experiment) do
      Split::Experiment.new('link_color', :alternatives => ['red', 'blue', 'green'], :cohorting_block => ['red', 'blue', 'green'])
    end
  
    let(:red_alternative) { Split::Alternative.new('red', 'link_color') }

    it "cohorts the first user into the first alternative defined in cohorting_block" do
      expect(Split::Algorithms::SystematicSampling.choose_alternative(valid_experiment).name).to equal "red"
    end

    it "cohorts the second user into the second alternative defined in cohorting_block" do
      red_alternative.increment_participation

      expect(Split::Algorithms::SystematicSampling.choose_alternative(valid_experiment).name).to equal "blue"
    end

    it "cohorts the fourth user into the first alternative defined in cohorting_block" do
      red_alternative.increment_participation
      red_alternative.increment_participation
      red_alternative.increment_participation

      expect(Split::Algorithms::SystematicSampling.choose_alternative(valid_experiment).name).to equal "red"
    end
  end

  context "for an experiment with no cohorting_block defined" do
    let!(:missing_config_experiment) do
      Split::Experiment.new('link_color', :alternatives => ['red', 'blue', 'green'])
    end

    it "Throws argument error with descriptive message" do
      expect { Split::Algorithms::SystematicSampling.choose_alternative(missing_config_experiment).name }
        .to raise_error(ArgumentError, "Experiment configuration is missing cohorting_block array")
    end
  end

  context "for an experiment with invalid cohorting_block defined" do 
    let!(:invalid_config_experiment) do
      Split::Experiment.new('link_color', :alternatives => ['red', 'blue', 'green'], :cohorting_block => ['notarealalternative', 'blue', 'green'])
    end

    it "Throws argument error with descriptive message" do
      expect { Split::Algorithms::SystematicSampling.choose_alternative(invalid_config_experiment).name }
        .to raise_error(ArgumentError, "Invalid cohorting_block: 'notarealalternative' is not an experiment alternative")
    end
  end
end
