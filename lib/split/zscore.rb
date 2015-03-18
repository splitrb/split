module Split
  module Zscore

    include Math

    def self.calculate(p1, n1, p2, n2)
      # p_1 = Pa = proportion of users who converted within the experiment split (conversion rate)
      # p_2 = Pc = proportion of users who converted within the control split (conversion rate)
      # n_1 = Na = the number of impressions within the experiment split
      # n_2 = Nc = the number of impressions within the control split
      # s_1 = SEa = standard error of p_1, the estiamte of the mean
      # s_2 = SEc = standard error of p_2, the estimate of the control
      # s_p = SEp = standard error of p_1 - p_2, assuming a pooled variance
      # s_unp = SEunp = standard error of p_1 - p_2, assuming unpooled variance

      p_1 = p1.to_f
      p_2 = p2.to_f

      n_1 = n1.to_f
      n_2 = n2.to_f

      # Perform checks on data to make sure we can validly run our confidence tests
      if n_1 < 30 || n_2 < 30
        error = "Needs 30+ participants."
        return error
      elsif p_1 * n_1 < 5 || p_2 * n_2 < 5
        error = "Needs 5+ conversions."
        return error
      end

      # Formula for standard error: root(pq/n) = root(p(1-p)/n)
      s_1 = Math.sqrt((p_1)*(1-p_1)/(n_1))
      s_2 = Math.sqrt((p_2)*(1-p_2)/(n_2))

      # Formula for pooled error of the difference of the means: root(π*(1-π)*(1/na+1/nc)
      # π = (xa + xc) / (na + nc)
      pi = (p_1*n_1 + p_2*n_2)/(n_1 + n_2)
      s_p = Math.sqrt(pi*(1-pi)*(1/n_1 + 1/n_2))

      # Formula for unpooled error of the difference of the means: root(sa**2/na + sc**2/nc)
      s_unp = Math.sqrt(s_1**2 + s_2**2)

      # Boolean variable decides whether we can pool our variances
      pooled = s_1/s_2 < 2 && s_2/s_1 < 2

      # Assign standard error either the pooled or unpooled variance
      se = pooled ? s_p : s_unp

      # Calculate z-score
      z_score = (p_1 - p_2)/(se)

      return z_score

    end
  end
end
