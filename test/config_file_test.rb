# frozen_string_literal: true

require_relative "test_helper"
require "tempfile"

class ConfigFileTest < Minitest::Test
  def with_config(contents)
    file = Tempfile.new(["rubot", ".yml"])
    file.write(contents)
    file.flush
    yield file.path
  ensure
    file.close!
  end

  def setup
    Rubot.configure do |config|
      config.default_provider_name = nil
      config.default_model = nil
      config.run_job_queue_name = :default
      config.step_job_queue_name = :default
      config.resume_job_queue_name = :default
      config.features = {}
    end
  end

  def test_loads_plain_global_config
    with_config(<<~YAML) do |path|
      provider: gemini
      default_model: gemini-2.5-flash
      queues:
        run: ingestion
        step: execution
        resume: approvals
      features:
        admin_live_updates: false
    YAML
      config = Rubot::ConfigFile.load(path: path, environment: "development")

      assert_equal "gemini", config[:provider]
      assert_equal "gemini-2.5-flash", config[:default_model]
      assert_equal "ingestion", config.dig(:queues, :run)
      assert_equal false, config.dig(:features, :admin_live_updates)
    end
  end

  def test_merges_default_and_environment_sections
    with_config(<<~YAML) do |path|
      default:
        provider: openai
        queues:
          run: default
          step: steps
      production:
        default_model: gpt-5-mini
        queues:
          run: production_runs
    YAML
      config = Rubot::ConfigFile.load(path: path, environment: "production")

      assert_equal "openai", config[:provider]
      assert_equal "gpt-5-mini", config[:default_model]
      assert_equal "production_runs", config.dig(:queues, :run)
      assert_equal "steps", config.dig(:queues, :step)
    end
  end

  def test_apply_maps_yaml_settings_into_runtime_configuration
    with_config(<<~YAML) do |path|
      provider: openai
      default_model: gpt-5-mini
      queues:
        run: ingest
        step: steps
        resume: approvals
      features:
        admin_live_updates: false
    YAML
      config = Rubot::ConfigFile.load(path: path, environment: "test")
      Rubot::ConfigFile.apply(Rubot.configuration, config)

      assert_equal "openai", Rubot.configuration.default_provider_name
      assert_equal "gpt-5-mini", Rubot.configuration.default_model
      assert_equal "ingest", Rubot.configuration.run_job_queue_name
      assert_equal "steps", Rubot.configuration.step_job_queue_name
      assert_equal "approvals", Rubot.configuration.resume_job_queue_name
      assert_equal false, Rubot.configuration.features[:admin_live_updates]
    end
  end

  def test_rejects_unknown_top_level_keys
    with_config(<<~YAML) do |path|
      provider: openai
      unsupported: true
    YAML
      error = assert_raises(Rubot::ValidationError) do
        Rubot::ConfigFile.load(path: path, environment: "development")
      end

      assert_includes error.message, "Unsupported Rubot config keys"
    end
  end

  def test_rejects_unknown_queue_keys
    with_config(<<~YAML) do |path|
      queues:
        unknown: nope
    YAML
      error = assert_raises(Rubot::ValidationError) do
        Rubot::ConfigFile.load(path: path, environment: "development")
      end

      assert_includes error.message, "Unsupported Rubot queue keys"
    end
  end

  def test_live_updates_feature_flag_defaults_to_enabled
    Rubot.configure { |config| config.features = {} }

    assert_equal true, Rubot::LiveUpdates.send(:feature_enabled?, :admin_live_updates)
  end

  def test_live_updates_feature_flag_can_be_disabled
    Rubot.configure do |config|
      config.features = { admin_live_updates: false }
    end

    assert_equal false, Rubot::LiveUpdates.send(:feature_enabled?, :admin_live_updates)
  end
end
