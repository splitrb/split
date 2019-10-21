# frozen_string_literal: true

module Split
  module Persistence
    class DualAdapter
      def self.with_config(options={})
        self.config.merge!(options)
        self
      end

      def self.config
        @config ||= {}
      end

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

        @fallback_to_logged_out_adapter =
          self.class.config[:fallback_to_logged_out_adapter] || false
        @logged_in = logged_in.call(context)
        @logged_in_adapter = logged_in_adapter.new(context)
        @logged_out_adapter = logged_out_adapter.new(context)
        @active_adapter = @logged_in ? @logged_in_adapter : @logged_out_adapter
      end

      def keys
        if @fallback_to_logged_out_adapter
          (@logged_in_adapter.keys + @logged_out_adapter.keys).uniq
        else
          @active_adapter.keys
        end
      end

      def [](key)
        if @fallback_to_logged_out_adapter
          @logged_in && @logged_in_adapter[key] || @logged_out_adapter[key]
        else
          @active_adapter[key]
        end
      end

      def []=(key, value)
        if @fallback_to_logged_out_adapter
          @logged_in_adapter[key] = value if @logged_in
          old_value = @logged_out_adapter[key]
          @logged_out_adapter[key] = value

          decrement_participation(key, old_value) if decrement_participation?(old_value, value)
        else
          @active_adapter[key] = value
        end
      end

      def delete(key)
        if @fallback_to_logged_out_adapter
          @logged_in_adapter.delete(key)
          @logged_out_adapter.delete(key)
        else
          @active_adapter.delete(key)
        end
      end

      private

      def decrement_participation?(old_value, value)
        !old_value.nil? && !value.nil? && old_value != value
      end

      def decrement_participation(key, value)
        Split.redis.hincrby("#{key}:#{value}", 'participant_count', -1)
      end
    end
  end
end
