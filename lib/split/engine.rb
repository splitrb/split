module Split
  class Engine < ::Rails::Engine
    initializer "split" do |app|
      ActionController::Base.send :include, Split::Helper
      ActionController::Base.helper Split::Helper
    end
  end
end