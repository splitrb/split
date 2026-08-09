# frozen_string_literal: true

require "bigdecimal"
require "json"

module Split
  module DashboardHelpers
    def h(text)
      Rack::Utils.escape_html(text)
    end

    def active_overrides
      raw = request.cookies[Split::OVERRIDE_COOKIE_NAME]
      return {} if raw.nil? || raw.empty?

      overrides = JSON.parse(raw)
      overrides.is_a?(Hash) ? overrides : {}
    rescue JSON::ParserError
      {}
    end

    def write_overrides(overrides)
      if overrides.empty?
        response.delete_cookie(Split::OVERRIDE_COOKIE_NAME, path: "/")
      else
        response.set_cookie(Split::OVERRIDE_COOKIE_NAME, { value: overrides.to_json, path: "/" })
      end
    end

    def url(*path_parts)
      [ request.env["SCRIPT_NAME"], path_parts ].join("/").squeeze("/")
    end

    def number_to_percentage(number)
      round(number * 100)
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
