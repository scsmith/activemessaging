require "rails"

module ActiveMessaging
  class Railtie < Rails::Railtie
    initializer "activemessaging" do
      require "activemessaging/base"
      ActiveMessaging.load_activemessaging
      ActionDispatch::Callbacks.to_prepare do
        ActiveMessaging.reload_activemessaging
      end
    end
  end
end
