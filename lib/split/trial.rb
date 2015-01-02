module Split
  class Trial
    attr_accessor :experiment

    def initialize(attrs = {})
      self.experiment   = attrs.delete(:experiment)
      self.alternative  = attrs.delete(:alternative)

      @user             = attrs.delete(:user)
      @options          = attrs
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

    def complete!(goals, context = nil)
      goals = goals || []

      if alternative
        if goals.empty?
          alternative.increment_completion
        else
          goals.each {|g| alternative.increment_completion(g) }
        end

        context.send(Split.configuration.on_trial_complete, self) \
            if Split.configuration.on_trial_complete && context
      end
    end

    def record!
      if should_store_alternative?
        @user[@experiment.key] = @alternative.name
      end
    end

    def choose(context = nil)
      if @options[:override]
        self.alternative = @options[:override]
      elsif @options[:disabled]
        self.alternative = @experiment.control
      elsif @experiment.has_winner?
        self.alternative = @experiment.winner
      else
        cleanup_old_versions

        if exclude_user?
          self.alternative = @experiment.control
        elsif @user[@experiment.key]
          self.alternative = @user[@experiment.key]
        else
          self.alternative = @experiment.next_alternative

          self.alternative.increment_participation
          context.send(Split.configuration.on_trial_choose, self) \
              if Split.configuration.on_trial_choose && context
        end
      end
    end

    def choose!(context = nil)
      choose(context)
      record!

      alternative
    end

    private

    def should_store_alternative?
      if @options[:override] || @options[:disabled]
        Split.configuration.store_override
      else
        !exclude_user?
      end
    end

    def cleanup_old_versions
      if @experiment.version > 0
        keys = @user.keys.select { |k| k.match(Regexp.new(@experiment.name)) }
        keys_without_experiment(keys).each { |key| @user.delete(key) }
      end
    end

    def exclude_user?
      @options[:exclude] || @experiment.start_time.nil? || max_experiments_reached?
    end

    def max_experiments_reached?
      !Split.configuration.allow_multiple_experiments &&
          keys_without_experiment(@user.keys).length > 0
    end

    def keys_without_experiment(keys)
      keys.reject { |k| k.match(Regexp.new("^#{@experiment.key}(:finished)?$")) }
    end
  end
end
