module Split
  module Services
    module TimeBasedConversions

      def self.within_conversion_time_frame?(user_id, experiment_id)
        window_of_time_for_conversion = Split.configure.experiments[experiment_id].window_of_time_for_conversion
        time_of_engagement = Split.redis.get(user_id + "-" + experiment_id)

        (Time.now - time_of_engagement) <= window_of_time_for_conversion
      end

      def self.save_time_that_user_is_assigned(user_id, experiment_name)
        Split.redis.set(user_id + "-" + experiment_name, Time.now.to_s, ex: 2.months.from_now)
      end
    end
  end
end
