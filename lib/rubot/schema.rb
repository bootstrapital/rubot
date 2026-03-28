# frozen_string_literal: true

module Rubot
  class Schema
    Field = Struct.new(:name, :type, :required, :item_type, :schema, keyword_init: true)

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

      def hash(name, required: true, &block)
        schema = block ? Schema.build(&block) : nil
        field(name, :hash, required:, schema:)
      end

      def array(name, of: nil, required: true, &block)
        schema = block ? Schema.build(&block) : nil
        field(name, :array, required:, item_type: of, schema:)
      end

      def to_schema
        Schema.new(@fields)
      end

      private

      def field(name, type, required:, item_type: nil, schema: nil)
        @fields << Field.new(name:, type:, required:, item_type:, schema:)
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
        raw_type = field_schema[:type] || field_schema["type"]
        type = json_schema_type(raw_type)
        
        items_node = field_schema[:items] || field_schema["items"] || {}
        item_type = json_schema_type(items_node[:type] || items_node["type"])
        
        nested_schema =
          if type == :hash
            from_json_schema(field_schema)
          elsif type == :array && item_type == :hash
            from_json_schema(items_node)
          end

        Field.new(
          name: name.to_sym,
          type: type,
          required: required.include?(name.to_sym),
          item_type: item_type,
          schema: nested_schema
        )
      end

      new(fields)
    end

    def initialize(fields = [])
      @fields = fields
    end

    def validate!(payload, path = nil)
      payload = Rubot::HashUtils.symbolize(payload || {})

      fields.each do |field|
        field_path = path ? "#{path}.#{field.name}" : field.name.to_s
        value = payload[field.name]

        if value.nil?
          raise ValidationError, "Missing required field #{field_path}" if field.required
          next
        end

        validate_field!(field, value, field_path)
      end

      payload
    end

    def to_h
      fields.map do |field|
        {
          name: field.name,
          type: field.type,
          required: field.required,
          item_type: field.item_type,
          schema: field.schema&.to_h
        }.compact
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

    def validate_field!(field, value, path)
      expected = Builder::TYPE_NAMES.fetch(field.type)
      valid_type = expected.is_a?(Array) ? expected.any? { |t| value.is_a?(t) } : value.is_a?(expected)
      
      raise ValidationError, "#{path} must be a #{field.type}" unless valid_type

      if field.type == :hash && field.schema
        field.schema.validate!(value, path)
      elsif field.type == :array
        validate_array_items!(field, value, path)
      end
    end

    def validate_array_items!(field, value, path)
      if field.schema
        value.each_with_index do |item, index|
          field.schema.validate!(item, "#{path}.#{index}")
        end
      elsif field.item_type
        expected = Builder::TYPE_NAMES[field.item_type]
        return unless expected

        value.each_with_index do |item, index|
          valid_item = expected.is_a?(Array) ? expected.any? { |t| item.is_a?(t) } : item.is_a?(expected)
          raise ValidationError, "#{path}.#{index} items must be #{field.item_type}" unless valid_item
        end
      end
    end

    def json_schema_for(field)
      case field.type
      when :array
        schema = { type: "array" }
        if field.schema
          schema[:items] = field.schema.to_json_schema
        else
          item_type = Builder::TYPE_NAMES[field.item_type]
          schema[:items] = item_type ? { type: json_type_name(field.item_type) } : {}
        end
        schema
      when :hash
        field.schema ? field.schema.to_json_schema : { type: "object" }
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
