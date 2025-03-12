# frozen_string_literal: true

require "matrix"
require "rubystats"

module Split
  module Algorithms
    class << self
      def beta_distribution_rng(a, b)
        Rubystats::BetaDistribution.new(a, b).rng
      end
    end
  end
end
