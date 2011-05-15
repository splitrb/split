module Multivariate
  class Alternative
    attr_accessor :name

    def initialize(name)
      @name = name
    end

    def participant_count
      # number of users who have been given this alternative
    end

    def completed_count
      # number of users who have finished an experiment with this alternative
    end
  end
end