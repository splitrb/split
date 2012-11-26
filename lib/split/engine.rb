module Split
  class Engine < ::Rails::Engine
    initializer "split" do |app|
      ActionController::Base.send :include, Split::Helper
      ActionController::Base.helper Split::Helper
    end
  end

  if defined?(Rails) && @detect_mobile
    class Railtie < Rails::Railtie
      initializer "mobile_detect.insert_middleware" do |app|
        app.config.middleware.use "Rack::MobileDetect"
      end
    end
  end
end