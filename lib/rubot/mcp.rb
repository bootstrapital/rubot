# frozen_string_literal: true

module Rubot
  module MCP
    class Client
      def list_tools
        raise NotImplementedError, "#{self.class.name} must implement #list_tools"
      end

      def call_tool(_name, _arguments = {})
        raise NotImplementedError, "#{self.class.name} must implement #call_tool"
      end
    end

    class RemoteTool < Rubot::Tool
      class << self
        attr_reader :mcp_client, :mcp_tool_name, :mcp_tool_description, :mcp_input_json_schema, :mcp_output_json_schema

        def configure_mcp_tool(client:, tool_name:, description: nil, input_schema: nil, output_schema: nil)
          @mcp_client = client
          @mcp_tool_name = tool_name
          @mcp_tool_description = description
          @mcp_input_json_schema = input_schema || { type: "object", properties: {}, additionalProperties: true }
          @mcp_output_json_schema = output_schema || { type: "object", properties: {}, additionalProperties: true }
          description(description) if description
          @rubot_input_schema = Rubot::Schema.from_json_schema(@mcp_input_json_schema)
          @rubot_output_schema = Rubot::Schema.from_json_schema(@mcp_output_json_schema)
        end

        def audit_metadata
          super.merge(
            remote: true,
            remote_protocol: "mcp",
            remote_tool_name: mcp_tool_name
          ).compact
        end
      end

      def call(**input)
        self.class.mcp_client.call_tool(self.class.mcp_tool_name, input)
      end
    end

    class ToolRegistry
      def initialize(client:, namespace: "MCP")
        @client = client
        @namespace = namespace
      end

      def discover
        tool_namespace = ensure_namespace(@namespace)

        Array(@client.list_tools).map do |descriptor|
          normalized = Rubot::HashUtils.symbolize(descriptor)
          class_name = normalize_class_name(normalized[:name])
          tool_class =
            if tool_namespace.const_defined?(class_name, false)
              tool_namespace.const_get(class_name, false)
            else
              tool_namespace.const_set(class_name, Class.new(RemoteTool))
            end

          tool_class.configure_mcp_tool(
            client: @client,
            tool_name: normalized[:name],
            description: normalized[:description],
            input_schema: normalized[:input_schema] || normalized[:parameters],
            output_schema: normalized[:output_schema]
          )
          tool_class
        end
      end

      private

      def ensure_namespace(namespace_name)
        if Rubot.const_defined?(namespace_name, false)
          Rubot.const_get(namespace_name, false)
        else
          Rubot.const_set(namespace_name, Module.new)
        end
      end

      def normalize_class_name(name)
        segments = name.to_s.split(/[^a-zA-Z0-9]+/).reject(&:empty?)
        "#{segments.map { |segment| segment[0].upcase + segment[1..] }.join}Tool"
      end
    end
  end
end
