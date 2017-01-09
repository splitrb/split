# frozen_string_literal: true
module Split
  module Persistence
    class DualAdapter
      extend Forwardable
      def_delegators :@adapter, :keys, :[], :multi_get, :[]=, :delete

      def initialize(context)
        unless (logged_in = self.class.config[:logged_in])
          raise 'Please configure :logged_in'
        end
        unless (logged_in_adapter = self.class.config[:logged_in_adapter])
          raise 'Please configure :logged_in_adapter'
        end
        unless (logged_out_adapter = self.class.config[:logged_out_adapter])
          raise 'Please configure :logged_out_adapter'
        end

        @adapter =
          if logged_in.call(context)
            logged_in_adapter.new(context)
          else
            logged_out_adapter.new(context)
          end
      end

      def self.with_config(options = {})
        config.merge!(options)
        self
      end

      def self.config
        @config ||= {}
      end
    end
  end
end
