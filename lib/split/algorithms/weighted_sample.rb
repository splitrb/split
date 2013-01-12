module Split
  module Algorithms
    module WeightedSample
      def self.choose_alternative(experiment)
        weights = experiment.alternatives.map(&:weight)

        total = weights.inject(:+)
        point = rand * total

        experiment.alternatives.zip(weights).each do |n,w|
          return n if w >= point
          point -= w
        end
      end
    end
  end
end