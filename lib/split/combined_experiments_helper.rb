# frozen_string_literal: true
module Split
  module CombinedExperimentsHelper
    def ab_combined_test(metric_descriptor, control = nil, *alternatives)
      return nil unless experiment = find_combined_experiment(metric_descriptor)
      raise(Split::InvalidExperimentsFormatError, 'Unable to find experiment #{metric_descriptor} in configuration') if experiment[:combined_experiments].nil?

      alternative = nil
      experiment[:combined_experiments].each do |combined_experiment|
        if alternative.nil?
          if control
            alternative = ab_test(combined_experiment, control, alternatives)
          else
            normalized_alternatives = Split::Configuration.new.normalize_alternatives(experiment[:alternatives])
            alternative = ab_test(combined_experiment, normalized_alternatives[0], *normalized_alternatives[1])
          end
        else
          ab_test(combined_experiment, [{alternative => 1}])
        end
      end
    end

    def find_combined_experiment(metric_descriptor)
      raise(Split::InvalidExperimentsFormatError, 'Invalid descriptor class (String or Symbol required)') unless metric_descriptor.class == String || metric_descriptor.class == Symbol
      raise(Split::InvalidExperimentsFormatError, 'Enable configuration') unless Split.configuration.enabled
      raise(Split::InvalidExperimentsFormatError, 'Enable `allow_multiple_experiments`') unless Split.configuration.allow_multiple_experiments
      experiment = Split::configuration.experiments[metric_descriptor.to_sym]
    end
  end
end
