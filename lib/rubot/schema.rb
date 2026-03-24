# frozen_string_literal: true

module Rubot
  class Schema
    Field = Struct.new(:name, :type, :required, :item_type, keyword_init: true)

    class Builder
      TYPE_NAMES = {
        string: String,
        integer: Integer,
        float: Numeric,
        boolean: [TrueClass, FalseClass],
        hash: Hash,
        array: Array
      }.freeze

      def initialize
        @fields = []
      end

      def string(name, required: true)
        field(name, :string, required:)
      end

      def integer(name, required: true)
        field(name, :integer, required:)
      end

      def float(name, required: true)
        field(name, :float, required:)
      end

      def boolean(name, required: true)
        field(name, :boolean, required:)
      end

      def hash(name, required: true)
        field(name, :hash, required:)
      end

      def array(name, of:, required: true)
        field(name, :array, required:, item_type: of)
      end

      def to_schema
        Schema.new(@fields)
      end

      private

      def field(name, type, required:, item_type: nil)
        @fields << Field.new(name:, type:, required:, item_type:)
      end
    end

    attr_reader :fields

    def self.build(&block)
      builder = Builder.new
      builder.instance_eval(&block) if block
      builder.to_schema
    end

    def self.from_json_schema(schema)
      normalized = schema || {}
      properties = normalized[:properties] || normalized["properties"] || {}
      required = Array(normalized[:required] || normalized["required"]).map(&:to_sym)

      fields = properties.map do |name, field_schema|
        field_schema = field_schema || {}
        type = json_schema_type(field_schema[:type] || field_schema["type"])
        item_type = json_schema_type((field_schema[:items] || field_schema["items"] || {})[:type] || (field_schema[:items] || field_schema["items"] || {})["type"])
        Field.new(name: name.to_sym, type: type, required: required.include?(name.to_sym), item_type: item_type)
      end

      new(fields)
    end

    def initialize(fields = [])
      @fields = fields
    end

    def validate!(payload)
      payload = symbolize_hash(payload || {})

      fields.each do |field|
        value = payload[field.name]
        if value.nil?
          raise ValidationError, "Missing required field #{field.name}" if field.required
          next
        end

        validate_type!(field, value)
      end

      payload
    end

    def to_h
      fields.map do |field|
        {
          name: field.name,
          type: field.type,
          required: field.required,
          item_type: field.item_type
        }
      end
    end

    def to_json_schema
      {
        type: "object",
        properties: fields.each_with_object({}) do |field, memo|
          memo[field.name] = json_schema_for(field)
        end,
        required: fields.select(&:required).map(&:name),
        additionalProperties: false
      }
    end

    private

    def self.json_schema_type(type)
      case type
      when "string" then :string
      when "integer" then :integer
      when "number" then :float
      when "boolean" then :boolean
      when "object" then :hash
      when "array" then :array
      else :string
      end
    end

    def symbolize_hash(payload)
      payload.each_with_object({}) do |(key, value), memo|
        memo[key.respond_to?(:to_sym) ? key.to_sym : key] = value
      end
    end

    def validate_type!(field, value)
      if field.type == :array
        raise ValidationError, "#{field.name} must be an Array" unless value.is_a?(Array)
        validate_array_items!(field, value)
        return
      end

      expected = Builder::TYPE_NAMES.fetch(field.type)
      return if expected.is_a?(Array) ? expected.any? { |type| value.is_a?(type) } : value.is_a?(expected)

      raise ValidationError, "#{field.name} must be a #{field.type}"
    end

    def validate_array_items!(field, value)
      expected = Builder::TYPE_NAMES[field.item_type]
      return unless expected

      invalid = value.find do |item|
        expected.is_a?(Array) ? expected.none? { |type| item.is_a?(type) } : !item.is_a?(expected)
      end

      return if invalid.nil?

      raise ValidationError, "#{field.name} items must be #{field.item_type}"
    end

    def json_schema_for(field)
      case field.type
      when :array
        schema = { type: "array" }
        item_type = Builder::TYPE_NAMES[field.item_type]
        schema[:items] = item_type ? { type: json_type_name(field.item_type) } : {}
        schema
      else
        { type: json_type_name(field.type) }
      end
    end

    def json_type_name(type)
      case type
      when :string then "string"
      when :integer then "integer"
      when :float then "number"
      when :boolean then "boolean"
      when :hash then "object"
      when :array then "array"
      else "string"
      end
    end
  end
end
