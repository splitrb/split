module Split
  module DashboardHelpers
    def url(*path_parts)
      [ path_prefix, path_parts ].join("/").squeeze('/')
    end

    def path_prefix
      request.env['SCRIPT_NAME']
    end

    def number_to_percentage(number, precision = 2)
      round(number * 100)
    end

    def round(number, precision = 2)
      BigDecimal.new(number.to_s).round(precision).to_f
    end

    def confidence_level(z_score)
      return z_score if z_score.is_a? String

      z = round(z_score.to_s.to_f, 3)
      if z > 0.0
        if z < 1.96
          'no confidence'
        elsif z < 2.57
          '95% confidence'
        elsif z < 3.29
          '99% confidence'
        else
          '99.9% confidence'
        end
      elsif z < 0.0
        if z > -1.96
          'no confidence'
        elsif z > -2.57
          '95% confidence'
        elsif z > -3.29
          '99% confidence'
        else
          '99.9% confidence'
        end
      else
        "No Change"
      end
    end
  end
end