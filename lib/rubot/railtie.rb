# frozen_string_literal: true

require "rails/railtie"
require_relative "engine"
require_relative "config_file"

module Rubot
  class Railtie < Rails::Railtie
    config.rubot = ActiveSupport::OrderedOptions.new

    initializer "rubot.load_config_file" do
      environment = Rails.env if defined?(Rails) && Rails.respond_to?(:env)
      path = Rails.root.join("config", "rubot.yml") if defined?(Rails) && Rails.respond_to?(:root)
      next unless path

      Rubot::ConfigFile.apply(Rubot.configuration, Rubot::ConfigFile.load(path:, environment:))
    end

    initializer "rubot.configure" do
      Rubot.configure do |config|
        config.store ||= Stores::MemoryStore.new
        config.event_subscriber = lambda do |_run, event|
          ActiveSupport::Notifications.instrument("rubot.event", event.to_h)
        end
      end
    end

    rake_tasks do
      load File.expand_path("../tasks/rubot_eval.rake", __dir__)
    end
  end
end
