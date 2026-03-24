# frozen_string_literal: true

require "rails/engine"

module Rubot
  class Engine < Rails::Engine
    isolate_namespace Rubot

    initializer "rubot.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        helper Rubot::UiHelper if defined?(Rubot::UiHelper)
      end
    end
  end
end
