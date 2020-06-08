# frozen_string_literal: true
module Split
  class Trial
    attr_accessor :goals
    attr_accessor :experiment
    attr_writer :metadata

    def initialize(attrs = {})
      self.experiment   = attrs.delete(:experiment)
      self.alternative  = attrs.delete(:alternative)
      self.metadata  = attrs.delete(:metadata)
      self.goals = attrs.delete(:goals) || []

      @user             = attrs.delete(:user)
      @options          = attrs

      @alternative_choosen = false
    end

    def metadata
      @metadata ||= experiment.metadata[alternative.name] if experiment.metadata
    end

    def alternative
      @alternative ||=  if @experiment.has_winner?
                          @experiment.winner
                        end
    end

    def alternative=(alternative)
      @alternative = if alternative.kind_of?(Split::Alternative)
        alternative
      else
        @experiment.alternatives.find{|a| a.name == alternative }
      end
    end

    def complete!(context = nil)
      if alternative
        if within_conversion_time_frame?
          if Array(goals).empty?
            alternative.increment_completion
          else
            Array(goals).each {|g| alternative.increment_completion(g) }
          end
        end

        delete_time_of_assignment_key
        run_callback context, Split.configuration.on_trial_complete
      end
    end

    # Choose an alternative, add a participant, and save the alternative choice on the user. This
    # method is guaranteed to only run once, and will skip the alternative choosing process if run
    # a second time.
    def choose!(context = nil)
      @user.cleanup_old_experiments!
      # Only run the process once
      return alternative if @alternative_choosen

      new_participant = @user[@experiment.key].nil?
      if override_is_alternative?
        self.alternative = @options[:override]
        if should_store_alternative? && !@user[@experiment.key]
          self.alternative.increment_participation
        end
      elsif @options[:disabled] || Split.configuration.disabled?
        self.alternative = @experiment.control
      elsif @experiment.has_winner?
        self.alternative = @experiment.winner
      else
        cleanup_old_versions

        if exclude_user?
          self.alternative = @experiment.control
        else
          self.alternative = @user[@experiment.key]
          if alternative.nil?
            if @experiment.cohorting_disabled?
              self.alternative = @experiment.control
            else
              self.alternative = @experiment.next_alternative

              # Increment the number of participants since we are actually choosing a new alternative
              self.alternative.increment_participation

              save_time_that_user_is_assigned
              run_callback context, Split.configuration.on_trial_choose
            end
          end
        end
      end

      @user[@experiment.key] = alternative.name unless @experiment.has_winner? || !should_store_alternative? || (new_participant && @experiment.cohorting_disabled?)
      @alternative_choosen = true
      run_callback context, Split.configuration.on_trial unless @options[:disabled] || Split.configuration.disabled? || (new_participant && @experiment.cohorting_disabled?) 
      alternative
    end

    def within_conversion_time_frame?
      if !@within_conversion_time_frame.nil?
        @within_conversion_time_frame
      else
        @within_conversion_time_frame = begin
          window_of_time_for_conversion_in_minutes = Split.configuration.experiments.dig(@experiment.name, "window_of_time_for_conversion_in_minutes")

          return true if window_of_time_for_conversion_in_minutes.nil?

          time_of_assignment = Time.parse(@user["#{@experiment.key}:time_of_assignment"])
          (Time.now - time_of_assignment)/60 <= window_of_time_for_conversion_in_minutes
        end
      end
    end

    private

    def delete_time_of_assignment_key
      @user.delete("#{@experiment.key}:time_of_assignment")
    end

    def save_time_that_user_is_assigned
      @user["#{@experiment.key}:time_of_assignment"] = Time.now.to_s
    end

    def run_callback(context, callback_name)
      context.send(callback_name, self) if callback_name && context.respond_to?(callback_name, true)
    end

    def override_is_alternative?
      @experiment.alternatives.map(&:name).include?(@options[:override])
    end

    def should_store_alternative?
      if @options[:override] || @options[:disabled]
        Split.configuration.store_override
      else
        !exclude_user?
      end
    end

    def cleanup_old_versions
      if @experiment.version > 0
        @user.cleanup_old_versions!(@experiment)
      end
    end

    def exclude_user?
      @options[:exclude] || @experiment.start_time.nil? || @user.max_experiments_reached?(@experiment.key)
    end
  end
end
