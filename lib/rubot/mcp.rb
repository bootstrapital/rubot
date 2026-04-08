# frozen_string_literal: true

module Rubot
  module MCP
    class << self
      def discover(client, namespace: "MCP")
        ToolRegistry.new(client: client, namespace: namespace).discover
      end

      def call_tool(client, name, arguments = {})
        result = normalize_keys(client.call_tool(name, arguments))

        if result.is_a?(Hash) && result[:isError]
          raise MCPError.new(
            "MCP tool error: #{extract_error_message(result)}",
            details: { name: name, arguments: arguments, result: result }
          )
        end

        result
      rescue StandardError => e
        raise e if e.is_a?(MCPError)
        raise MCPError.new(e.message, details: { name: name, arguments: arguments, original_exception: e.class.name })
      end

      private

      def normalize_keys(value)
        case value
        when Hash
          Rubot::HashUtils.symbolize(value)
        when Array
          value.map { |item| normalize_keys(item) }
        else
          value
        end
      end

      def extract_error_message(result)
        content = Array(result[:content]).find { |c| c[:type] == "text" }
        content ? content[:text] : "Unknown remote error"
      end
    end

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
        Rubot::MCP.call_tool(self.class.mcp_client, self.class.mcp_tool_name, input)
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

    class Server
      def initialize(operations: [])
        @operations = operations
      end

      def list_tools
        @operations.map do |op|
          {
            name: op.name.to_s.gsub("::", "__"),
            description: op.description || "Rubot Operation: #{op.name}",
            inputSchema: op.input_schema.to_json_schema
          }
        end
      end

      def call_tool(name, arguments = {})
        op_name = name.gsub("__", "::")
        op = @operations.find { |o| o.name == op_name }
        
        raise "Operation not found: #{name}" unless op

        run = op.launch(payload: arguments)

        if run.completed?
          {
            content: [{ type: "text", text: JSON.generate(run.output) }],
            isError: false
          }
        elsif run.failed?
          {
            content: [{ type: "text", text: "Run failed: #{JSON.generate(run.error)}" }],
            isError: true
          }
        else
          {
            content: [{ type: "text", text: "Run status: #{run.status}. ID: #{run.id}" }],
            isError: false
          }
        end
      end
    end

    class StandardIOServer < Server
      def run
        while (line = STDIN.gets)
          request = JSON.parse(line) rescue next
          response = handle_request(request)
          STDOUT.puts(JSON.generate(response))
          STDOUT.flush
        end
      end

      private

      def handle_request(request)
        id = request["id"]
        method = request["method"]
        params = request["params"] || {}

        result =
          case method
          when "tools/list"
            { tools: list_tools }
          when "tools/call"
            call_tool(params["name"], params["arguments"] || {})
          else
            { error: { code: -32601, message: "Method not found" } }
          end

        { jsonrpc: "2.0", id: id, result: result }
      end
    end
  end
end
