module Split
  module Algorithms
    module WeightedSample
      
      def self.rand_one_alternative(weight_mapping, total)
        point = rand * total
        weight_mapping.each do |n,w|
          return n if w >= point
          point -= w
        end
      end
        
      def self.choose_alternatives(experiment, num_participants)
        weights = experiment.alternatives.map(&:weight)
        total = weights.inject(:+)
        weight_mapping = experiment.alternatives.zip(weights)
        
        alternatives_arr = []
        num_participants.times do |i|
          alternatives_arr << rand_one_alternative(weight_mapping, total)
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