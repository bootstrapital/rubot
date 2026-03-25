# frozen_string_literal: true

require "rails/engine"

module Rubot
  # Provisional Rails surface: the engine is mountable today, but route
  # shape and packaging may change while the admin UI is extracted in v0.2.
  class Engine < Rails::Engine
    isolate_namespace Rubot

    initializer "rubot.assets" do |app|
      next unless app.config.respond_to?(:assets)

      app.config.assets.precompile += %w[rubot/application.css]
    end

    initializer "rubot.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        helper Rubot::UiHelper if defined?(Rubot::UiHelper)
      end
    end
  end
end
