module Split
  class Engine < ::Rails::Engine
    initializer "split" do |app|
      if Split.configuration.include_rails_helper
        ActionController::Base.send :include, Split::Helper
        ActionController::Base.helper Split::Helper
      end
    end
  end
end
