# frozen_string_literal: true

if defined?(RubyLLM)
  RubyLLM.configure do |config|
    config.gemini_api_key = ENV["GEMINI_API_KEY"] if ENV["GEMINI_API_KEY"].to_s.strip != ""
    config.logger = Rails.logger if config.respond_to?(:logger=)
  end
end

Rubot.configure do |config|
  config.store = Rubot::Stores::ActiveRecordStore.new

  next unless ENV["GEMINI_API_KEY"].to_s.strip != ""

  config.provider = Rubot::Providers::RubyLLM.new(provider_name: "gemini")
  config.default_provider_name = "gemini"
  config.default_model = ENV.fetch("RUBOT_MODEL", "gemini-2.5-flash")
end
