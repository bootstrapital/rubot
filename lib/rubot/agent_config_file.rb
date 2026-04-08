# frozen_string_literal: true

require "yaml"

module Rubot
  module AgentConfigFile
    SUPPORTED_KEYS = %i[instructions model description tags metadata].freeze

    class << self
      def load(path:)
        return {} unless path && File.exist?(path)

        raw = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
        raw ||= {}
        raise Rubot::ValidationError, "Rubot agent config must be a YAML mapping" unless raw.is_a?(Hash)

        config = Rubot::HashUtils.symbolize(raw)
        validate_supported_keys!(config)
        normalize_config(config)
      end

      private

      def validate_supported_keys!(config)
        unknown = config.keys - SUPPORTED_KEYS
        return if unknown.empty?

        raise Rubot::ValidationError, "Unsupported Rubot agent config keys: #{unknown.map(&:to_s).sort.join(', ')}"
      end

      def normalize_config(config)
        normalized = config.dup

        validate_string!(normalized, :instructions)
        validate_string!(normalized, :model)
        validate_string!(normalized, :description)
        normalize_tags!(normalized)
        normalize_metadata!(normalized)

        normalized
      end

      def validate_string!(config, key)
        return unless config.key?(key)
        return if config[key].is_a?(String)

        raise Rubot::ValidationError, "Rubot agent config #{key} must be a string"
      end

      def normalize_tags!(config)
        return unless config.key?(:tags)

        tags = config[:tags]
        raise Rubot::ValidationError, "Rubot agent config tags must be an array of strings" unless tags.is_a?(Array) && tags.all? { |tag| tag.is_a?(String) }

        config[:tags] = tags.dup.freeze
      end

      def normalize_metadata!(config)
        return unless config.key?(:metadata)

        metadata = config[:metadata]
        raise Rubot::ValidationError, "Rubot agent config metadata must be a mapping" unless metadata.is_a?(Hash)

        config[:metadata] = Rubot::HashUtils.symbolize(metadata).freeze
      end
    end
  end
end
