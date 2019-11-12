# frozen_string_literal: true
module Split
  class Engine < ::Rails::Engine
    initializer "split" do |app|
      if Split.configuration.include_rails_helper
        ActiveSupport.on_load(:action_controller) do
          ::ActionController::Base.send :include, Split::Helper
          ::ActionController::Base.helper Split::Helper
          ::ActionController::Base.send :include, Split::CombinedExperimentsHelper
          ::ActionController::Base.helper Split::CombinedExperimentsHelper
        end
      end
    end
  end
end
