# Example driver code.

module Split
  module Backends
    module Driver
      
      def self.included(klass)
        raise Split::Error("Don't include the driver!")  
      end
      
      def server=(url)
      end

      def server  
      end

      def clean
      end

      def exists?(experiment_name)
      end

      def find(experiment_name)
      end

      def save(experiment_name, alternatives, time)
      end

      def alternatives(experiment_name)
      end

      def start_time(experiment_name)
      end

      def delete(experiment_name)
      end

      def version(experiment_name)
      end
      
      def winner(experiment_name)
      end
      
      def set_winner(experiment_name, winner)
      end
      
      def reset_winner(experiment_name)
      end
      
      def all_experiments
      end
      
      def increment_version(experiment_name)
      end
      
      def alternative_names(experiment_name)
      end

      def alternative(experiment_name, alternative)
      end

      def alternative_participant_count(experiment_name, alternative)
      end

      def alternative_completed_count(experiment_name, alternative)
      end
      
      def incr_alternative_participant_count(experiment_name, alternative)
      end

      def incr_alternative_completed_count(experiment_name, alternative)
      end

      def reset(experiment_name, alternative)
      end
    end
  end
end