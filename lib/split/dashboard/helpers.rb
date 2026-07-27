# frozen_string_literal: true

require "bigdecimal"

module Split
  module DashboardHelpers
    def h(text)
      Rack::Utils.escape_html(text)
    end

    def url(*path_parts)
      [ request.env["SCRIPT_NAME"], path_parts ].join("/").squeeze("/")
    end

    def number_to_percentage(number)
      round(number * 100)
    end

    AlternativeRow = Struct.new(:alternative, :info, :participants, :unfinished, :completed)

    def alternative_rows(experiment, goal = nil)
      experiment.alternatives.map do |alternative|
        AlternativeRow.new(
          alternative,
          alternative.extra_info || {},
          alternative.participant_count,
          alternative.unfinished_count,
          alternative.completed_count(goal)
        )
      end
    end

    def extra_info_totals(infos)
      infos.flat_map(&:keys).uniq.to_h do |column|
        values = infos.map { |info| info[column] }.compact
        [column, values.any? && values.all?(Numeric) ? values.sum : "N/A"]
      end
    end

    def conversion_delta_tag(experiment, alternative, goal = nil)
      return "" if alternative.control?

      control_rate = experiment.control.conversion_rate(goal)
      rate = alternative.conversion_rate(goal)
      return "" if control_rate <= 0 || rate == control_rate

      css = rate > control_rate ? "better" : "worse"
      sign = rate > control_rate ? "+" : ""
      %(<span class="#{css}">#{sign}#{number_to_percentage(rate / control_rate - 1)}%</span>)
    end

    def round(number, precision = 2)
      begin
        BigDecimal(number.to_s)
      rescue ArgumentError
        BigDecimal(0)
      end.round(precision).to_f
    end

    def confidence_level(z_score)
      return z_score if z_score.is_a? String

      z = round(z_score.to_s.to_f, 3).abs

      if z >= 2.58
        "99% confidence"
      elsif z >= 1.96
        "95% confidence"
      elsif z >= 1.65
        "90% confidence"
      else
        "Insufficient confidence"
      end
    end
  end
end
