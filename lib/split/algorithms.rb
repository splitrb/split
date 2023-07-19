# frozen_string_literal: true

begin
  require "matrix"
rescue LoadError => error
  if error.message.match?(/matrix/)
    $stderr.puts "You don't have matrix installed in your application. Please add it to your Gemfile and run bundle install"
    raise
  end
end

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
