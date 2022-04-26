# frozen_string_literal: true
module Split
  module Algorithms
    module SystematicSampling
      def self.choose_alternative(experiment)
        block = experiment.cohorting_block
        raise ArgumentError, "Experiment configuration is missing cohorting_block array" unless block
        index = experiment.participant_count % block.length
        chosen_alternative = block[index]
        alt = experiment.alternatives.find do |alt|
          alt.name == chosen_alternative
        end
        raise ArgumentError, "Invalid cohorting_block: '#{chosen_alternative}' is not an experiment alternative" unless alt
        alt
      end
    end
  end
end
