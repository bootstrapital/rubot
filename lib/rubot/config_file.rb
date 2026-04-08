# frozen_string_literal: true

require "yaml"

module Rubot
  module ConfigFile
    SUPPORTED_KEYS = %i[provider default_model queues features].freeze
    ENVIRONMENT_KEY = "default"

    class << self
      def load(path:, environment: nil)
        return {} unless File.exist?(path)

        raw = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
        raw ||= {}
        raise Rubot::ValidationError, "Rubot config must be a YAML mapping" unless raw.is_a?(Hash)

        normalized = deep_symbolize(raw)
        validate_top_level_keys!(normalized, environment)

        config =
          if environment_keyed?(normalized, environment)
            merge_environment_layers(normalized, environment)
          else
            normalized
          end

        validate_supported_keys!(config)
        normalize_config(config)
      end

      def apply(configuration, config)
        return configuration if config.nil? || config.empty?

        configuration.default_provider_name = config[:provider] if config.key?(:provider)
        configuration.default_model = config[:default_model] if config.key?(:default_model)

        if config.key?(:queues)
          queues = config[:queues]
          configuration.run_job_queue_name = queues[:run] if queues.key?(:run)
          configuration.step_job_queue_name = queues[:step] if queues.key?(:step)
          configuration.resume_job_queue_name = queues[:resume] if queues.key?(:resume)
        end

        configuration.features = configuration.features.merge(config[:features]) if config.key?(:features)
        configuration
      end

      private

      def environment_keyed?(config, environment)
        keys = config.keys.map(&:to_s)
        keys.include?(ENVIRONMENT_KEY) || (environment && keys.include?(environment.to_s))
      end

      def merge_environment_layers(config, environment)
        merged = {}
        merged = shallow_merge(merged, expect_mapping(config[ENVIRONMENT_KEY.to_sym], ENVIRONMENT_KEY)) if config.key?(ENVIRONMENT_KEY.to_sym)
        merged = shallow_merge(merged, expect_mapping(config[environment.to_sym], environment)) if environment && config.key?(environment.to_sym)
        merged
      end

      def expect_mapping(value, key_name)
        case value
        when nil
          {}
        when Hash
          value
        else
          raise Rubot::ValidationError, "Rubot config environment #{key_name} must be a mapping"
        end
      end

      def validate_top_level_keys!(config, environment)
        return unless environment_keyed?(config, environment)

        unknown = config.keys.reject do |key|
          key.to_s == ENVIRONMENT_KEY || (environment && key.to_s == environment.to_s)
        end
        return if unknown.empty?

        raise Rubot::ValidationError, "Unsupported top-level Rubot config keys: #{unknown.map(&:to_s).sort.join(', ')}"
      end

      def validate_supported_keys!(config)
        unknown = config.keys - SUPPORTED_KEYS
        return if unknown.empty?

        raise Rubot::ValidationError, "Unsupported Rubot config keys: #{unknown.map(&:to_s).sort.join(', ')}"
      end

      def normalize_config(config)
        normalized = config.dup

        if normalized.key?(:queues)
          queues = normalized[:queues]
          raise Rubot::ValidationError, "Rubot config queues must be a mapping" unless queues.is_a?(Hash)

          unknown = queues.keys - %i[run step resume]
          raise Rubot::ValidationError, "Unsupported Rubot queue keys: #{unknown.map(&:to_s).sort.join(', ')}" if unknown.any?
        end

        if normalized.key?(:features)
          features = normalized[:features]
          raise Rubot::ValidationError, "Rubot config features must be a mapping" unless features.is_a?(Hash)
        end

        normalized
      end

      def shallow_merge(base, override)
        base.merge(override) do |_key, old_value, new_value|
          old_value.is_a?(Hash) && new_value.is_a?(Hash) ? old_value.merge(new_value) : new_value
        end
      end

      def deep_symbolize(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, item), memo|
            memo[key.to_sym] = deep_symbolize(item)
          end
        when Array
          value.map { |item| deep_symbolize(item) }
        else
          value
        end
      end
    end
  end
end
