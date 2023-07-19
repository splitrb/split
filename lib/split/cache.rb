# frozen_string_literal: true

module Split
  class Cache
    def self.clear
      @cache = nil
    end

    def self.fetch(namespace, key)
      return yield unless Split.configuration.cache

      @cache ||= {}
      @cache[namespace] ||= {}

      value = @cache[namespace][key]
      return value if value

      @cache[namespace][key] = yield
    end

    def self.clear_key(key)
      @cache&.keys&.each do |namespace|
        @cache[namespace]&.delete(key)
      end
    end
  end
end
