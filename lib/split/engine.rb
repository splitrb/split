# frozen_string_literal: true
module Split
  class Engine < ::Rails::Engine
    initializer "split" do |app|
      if Split.configuration.include_rails_helper
        ActiveSupport.on_load(:action_controller) do
          include Split::Helper
          helper Split::Helper
          include Split::CombinedExperimentsHelper
          helper Split::CombinedExperimentsHelper
        end
      end
    end
  end
end
