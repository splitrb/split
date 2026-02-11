# frozen_string_literal: true

module Split
  # Manages global cache invalidation across multiple processes using Redis timestamp.
  # The mechanism is opt-in: it activates only when
  # Split.configuration.cache_global_ts_check_interval is set.
  class CacheInvalidator
    class << self
      # Check global timestamp and clear cache if it has been updated.
      # No-op when cache_global_ts_check_interval is not configured.
      # @param cache [Split::Cache] the cache instance to potentially clear
      def check_and_clear_if_needed(cache)
        return unless check_interval

        now = Time.now

        # Skip if within check interval
        return if within_check_interval?(now)

        # Get global timestamp from Redis
        current_global_ts = fetch_global_timestamp

        # Clear cache if timestamp was updated
        cache.clear if timestamp_updated?(current_global_ts)

        # Update local timestamp and check time
        update_local_state(current_global_ts, now)
      end

      # Invalidate cache globally by updating the global timestamp.
      # No-op when cache_global_ts_check_interval is not configured.
      def invalidate
        return unless check_interval

        Split.redis.set(global_timestamp_key, Time.now.to_f)
      end

      # Reset local state (used when cache is cleared)
      def reset
        @global_cache_ts = nil
        @last_global_ts_check = nil
      end

      private
        def within_check_interval?(now)
          @last_global_ts_check && (now.to_f - @last_global_ts_check.to_f) < check_interval
        end

        def fetch_global_timestamp
          Split.redis.get(global_timestamp_key).to_f
        end

        def timestamp_updated?(current_global_ts)
          @global_cache_ts && current_global_ts > @global_cache_ts
        end

        def update_local_state(current_global_ts, now)
          @global_cache_ts = current_global_ts
          @last_global_ts_check = now
        end

        def global_timestamp_key
          "split:cache:global_ts"
        end

        def check_interval
          Split.configuration.cache_global_ts_check_interval
        end
    end
  end
end
