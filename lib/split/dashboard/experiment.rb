# frozen_string_literal: true

require "forwardable"
require "json"

module Split
  class DashboardExperiment
    def initialize(experiment, goal = nil)
      @experiment = experiment
      @goal = goal
    end

    def alternatives
      @alternatives ||= build_alternatives
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

    private
      def build_alternatives
        alternatives = @experiment.alternatives
        stored = Split.redis.pipelined do |pipe|
          alternatives.each { |alternative| pipe.hgetall(alternative.key) }
        end

        views = alternatives.zip(stored).map do |alternative, data|
          DashboardAlternative.new(alternative, @experiment, @goal, data)
        end
        views.each { |view| view.control = views.first }
      end
  end

  class DashboardAlternative
    extend Forwardable
    def_delegators :@alternative, :name, :control?

    attr_reader :participants, :unfinished, :completed, :extra_info, :p_winner
    attr_writer :control

    def initialize(alternative, experiment, goal, data)
      @alternative = alternative

      @participants = data["participant_count"].to_i
      @completed = data[alternative.set_field(goal)].to_i
      @unfinished = @participants - all_completed(data, experiment.goals)
      @p_winner = data[alternative.set_prob_field(goal)].to_f
      @extra_info = parse_extra_info(data["recorded_info"])
    end

    def conversion_rate
      return 0 if participants.zero?

      completed.to_f / participants
    end

    def conversion_delta
      return if control?

      control_rate = @control.conversion_rate
      return if control_rate <= 0 || conversion_rate == control_rate

      conversion_rate / control_rate - 1
    end

    def z_score
      return "N/A" if control?

      rate = conversion_rate
      control_rate = @control.conversion_rate
      return "N/A" if rate > 1 || control_rate > 1

      Split::Zscore.calculate(rate, participants, control_rate, @control.participants)
    end

    def winner?
      @alternative.experiment.winner.name == name
    end

    private
      def all_completed(data, goals)
        goals.reduce(data[@alternative.set_field(nil)].to_i) do |sum, goal|
          sum + data[@alternative.set_field(goal)].to_i
        end
      end

      def parse_extra_info(recorded_info)
        return {} unless recorded_info && recorded_info.length > 1

        begin
          JSON.parse(recorded_info)
        rescue
          {}
        end
      end
  end
end
