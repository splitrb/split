# frozen_string_literal: true
module Split
  module CombinedExperimentsHelper
    def ab_combined_test(metric_descriptor, control = nil, *alternatives)
      return nil unless experiment = find_combined_experiment(metric_descriptor)
      raise(Split::InvalidExperimentsFormatError, "Unable to find experiment #{metric_descriptor} in configuration") if experiment[:combined_experiments].nil?

      alternative = nil
      weighted_alternatives = nil
      experiment[:combined_experiments].each do |combined_experiment|
        if alternative.nil?
          if control
            alternative = ab_test(combined_experiment, control, alternatives)
          else
            normalized_alternatives = Split::Configuration.new.normalize_alternatives(experiment[:alternatives])
            alternative = ab_test(combined_experiment, normalized_alternatives[0], *normalized_alternatives[1])
          end
        else
          weighted_alternatives ||= experiment[:alternatives].each_with_object({}) do |alt, memo|
            alt = Alternative.new(alt, experiment[:name]).name
            memo[alt] = (alt == alternative ? 1 : 0)
          end

          ab_test(combined_experiment, [weighted_alternatives])
        end
      end
      alternative
    end

    def find_combined_experiment(metric_descriptor)
      raise(Split::InvalidExperimentsFormatError, 'Invalid descriptor class (String or Symbol required)') unless metric_descriptor.class == String || metric_descriptor.class == Symbol
      raise(Split::InvalidExperimentsFormatError, 'Enable configuration') unless Split.configuration.enabled
      raise(Split::InvalidExperimentsFormatError, 'Enable `allow_multiple_experiments`') unless Split.configuration.allow_multiple_experiments
      Split::configuration.experiments[metric_descriptor.to_sym]
    end
  end
end
