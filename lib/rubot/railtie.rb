# frozen_string_literal: true

require "rails/railtie"
require_relative "engine"

module Rubot
  class Railtie < Rails::Railtie
    config.rubot = ActiveSupport::OrderedOptions.new

    initializer "rubot.configure" do
      Rubot.configure do |config|
        config.store ||= Stores::MemoryStore.new
        config.event_subscriber = lambda do |_run, event|
          ActiveSupport::Notifications.instrument("rubot.event", event.to_h)
        end
      end
    end
  end
end
