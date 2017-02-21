require 'digest/murmurhash'
module Split
  module Algorithms
    module WeightedDeterministic
      def self.choose_alternative(experiment, split_id)
        hash = Digest::MurmurHash3_x64_128.rawdigest("#{experiment.key}:#{split_id}")

        weights = experiment.alternatives.map(&:weight)
        total = weights.inject(:+) * 100

        point = (hash % total)

        experiment.alternatives.zip(weights).each do |n,w|
          return n if w*100 > point
          point -= w*100
        end
      end
    end
  end
end