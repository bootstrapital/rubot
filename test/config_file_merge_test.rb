# frozen_string_literal: true

require_relative "test_helper"
require "tempfile"

class ConfigFileMergeTest < Minitest::Test
  def test_load_performs_shallow_merge_of_default_and_environment
    yaml = <<~YAML
      default:
        provider: openai
        queues:
          run: default
          step: default
      development:
        default_model: gpt-4
        queues:
          run: development
    YAML

    with_temp_config(yaml) do |path|
      config = Rubot::ConfigFile.load(path: path, environment: "development")

      assert_equal "openai", config[:provider]
      assert_equal "gpt-4", config[:default_model]
      assert_equal "development", config[:queues][:run]
      assert_equal "default", config[:queues][:step]
    end
  end

  def test_load_supports_plain_mapping_without_environments
    yaml = <<~YAML
      provider: anthropic
      default_model: claude-3
    YAML

    with_temp_config(yaml) do |path|
      config = Rubot::ConfigFile.load(path: path)

      assert_equal "anthropic", config[:provider]
      assert_equal "claude-3", config[:default_model]
    end
  end

  def test_load_raises_validation_error_for_unknown_top_level_keys
    yaml = <<~YAML
      default:
        provider: openai
      unknown_env:
        provider: other
    YAML

    with_temp_config(yaml) do |path|
      error = assert_raises(Rubot::ValidationError) do
        Rubot::ConfigFile.load(path: path, environment: "development")
      end
      assert_includes error.message, "Unsupported top-level Rubot config keys: unknown_env"
    end
  end

  def test_load_raises_validation_error_for_unsupported_config_keys
    yaml = <<~YAML
      default:
        unsupported_key: value
    YAML

    with_temp_config(yaml) do |path|
      error = assert_raises(Rubot::ValidationError) do
        Rubot::ConfigFile.load(path: path, environment: "development")
      end
      assert_includes error.message, "Unsupported Rubot config keys: unsupported_key"
    end
  end

  private

  def with_temp_config(content)
    temp = Tempfile.new(["rubot", ".yml"])
    temp.write(content)
    temp.flush
    yield temp.path
  ensure
    temp.close! if temp
  end
end
