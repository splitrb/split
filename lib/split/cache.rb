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

      # Take a local snapshot so a concurrent `clear` (which replaces @cache)
      # cannot make us dereference nil mid-fetch. Worst case we write into a
      # detached hash, which is simply an extra cache miss on the next fetch.
      cache = (@cache ||= {})
      namespace_cache = (cache[namespace] ||= {})

      value = namespace_cache[key]
      return value if value

      namespace_cache[key] = yield
    end

    def self.clear_key(key)
      # Invalidate globally for all processes
      CacheInvalidator.invalidate

      # Clear from local cache immediately. Snapshot @cache and its values
      # so a concurrent `clear` cannot nil it out mid-iteration.
      cache = @cache
      cache&.values&.each do |namespace_cache|
        namespace_cache.delete(key)
      end
    end
  end
end
