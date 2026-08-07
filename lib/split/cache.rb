# frozen_string_literal: true

module Split
  class Cache
    def self.clear
      @cache = nil
      CacheInvalidator.reset
    end

    def self.fetch(namespace, key)
      return yield unless Split.configuration.cache

      # Check global invalidation
      CacheInvalidator.check_and_clear_if_needed(self)

      @cache ||= {}
      @cache[namespace] ||= {}

      value = @cache[namespace][key]
      unless value
        value = yield
        @cache[namespace][key] = value
      end

      value
    end

    def self.clear_key(key)
      # Invalidate globally for all processes
      CacheInvalidator.invalidate

      # Clear from local cache immediately
      @cache&.keys&.each do |namespace|
        @cache[namespace]&.delete(key)
      end
    end
  end
end
