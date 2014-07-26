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

    def number_to_currency(number)
      "$#{round(number)}"
    end

    def round(number, precision = 2)
      BigDecimal.new(number.to_s).round(precision).to_f
    end

    def confidence_level(z_score)
      return z_score if z_score.is_a? String

      z = round(z_score.to_s.to_f, 3).abs

      if z >= 2.58
        '99% confidence'
      elsif z >= 1.96
        '95% confidence'
      elsif z >= 1.65
        '90% confidence'
      else
        'Insufficient confidence'
      end

    end

    def probability_confidence(probability)
      return probability if probability.is_a? String

      if probability >= 0.99 || probability <= 0.01
        '99% confidence'
      elsif probability >= 0.95 || probability <= 0.05
        '95% confidence'
      elsif probability >= 0.90 || probability <= 0.10
        '90% confidence'
      else
        'Insufficient confidence'
      end
    end
  end
end
