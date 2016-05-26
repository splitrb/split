module Split
  module Algorithms
    module WeightedSample
      
      def self.choose_alternatives(experiment, num_participants)
        weights = experiment.alternatives.map(&:weight)
        total = weights.inject(:+)
        weight_mapping = experiment.alternatives.zip(weights)
        
        alternatives_arr = []
        num_participants.times do |i|
          point = rand * total
          weight_mapping.each do |n,w|
            alternatives_arr << n if w >= point
            point -= w
          end
        end
        alternatives_arr
      end
      
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