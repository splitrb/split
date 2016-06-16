# frozen_string_literal: true
module Split
  module Persistence
    class DualAdapter
      extend Forwardable
      def_delegators :@adapter, :keys, :[], :[]=, :delete

      def initialize(context)
        if logged_in = self.class.config[:logged_in]
        else
          raise "Please configure :logged_in"
        end
        if logged_in_adapter = self.class.config[:logged_in_adapter]
        else
          raise "Please configure :logged_in_adapter"
        end
        if logged_out_adapter = self.class.config[:logged_out_adapter]
        else
          raise "Please configure :logged_out_adapter"
        end

        if logged_in.call(context)
          @adapter = logged_in_adapter.new(context)
        else
          @adapter = logged_out_adapter.new(context)
        end
      end

      def self.with_config(options={})
        self.config.merge!(options)
        self
      end

      def self.config
        @config ||= {}
      end

    end
  end
end
