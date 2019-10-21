# frozen_string_literal: true
# Selects alternative with minimum count of participants
# If all counts are even (i.e. all are minimum), samples from all possible alternatives

module Split
  module Algorithms
    module BlockRandomization
      class << self
        def choose_alternative(experiment)
          minimum_participant_alternatives(experiment.alternatives).sample
        end

        private

        def minimum_participant_alternatives(alternatives)
          alternatives_by_count = alternatives.group_by(&:participant_count)
          min_group = alternatives_by_count.min_by { |k, v| k }
          min_group.last
        end
      end
    end
  end
end
