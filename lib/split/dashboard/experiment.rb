# frozen_string_literal: true

require "forwardable"

module Split
  class DashboardExperiment
    def initialize(experiment, goal = nil)
      @experiment = experiment
      @goal = goal
    end

    def alternatives
      @alternatives ||= @experiment.alternatives.map do |alternative|
        DashboardAlternative.new(alternative, @experiment, @goal)
      end
    end

    def extra_columns
      @extra_columns ||= alternatives.flat_map { |alternative| alternative.extra_info.keys }.uniq
    end

    def extra_totals
      @extra_totals ||= extra_columns.to_h do |column|
        values = alternatives.map { |alternative| alternative.extra_info[column] }.compact
        [column, values.any? && values.all?(Numeric) ? values.sum : "N/A"]
      end
    end

    def total_participants
      alternatives.sum(&:participants)
    end

    def total_unfinished
      alternatives.sum(&:unfinished)
    end

    def total_completed
      alternatives.sum(&:completed)
    end
  end

  class DashboardAlternative
    extend Forwardable
    def_delegators :@alternative, :name, :control?

    attr_reader :participants, :unfinished, :completed, :extra_info

    def initialize(alternative, experiment, goal = nil)
      @alternative = alternative
      @experiment = experiment
      @goal = goal

      @participants = alternative.participant_count
      @unfinished = alternative.unfinished_count
      @completed = alternative.completed_count(goal)
      @extra_info = alternative.extra_info
    end

    def conversion_rate
      @conversion_rate ||= @alternative.conversion_rate(@goal)
    end

    def conversion_delta
      return if control?

      control_rate = @experiment.control.conversion_rate(@goal)
      return if control_rate <= 0 || conversion_rate == control_rate

      conversion_rate / control_rate - 1
    end

    def z_score
      @z_score ||= @alternative.z_score(@goal)
    end

    def p_winner
      @p_winner ||= @alternative.p_winner(@goal)
    end

    def winner?
      @experiment.winner.name == name
    end
  end
end
