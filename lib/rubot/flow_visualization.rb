# frozen_string_literal: true

module Rubot
  module FlowVisualization
    Node = Struct.new(:id, :label, :kind, :group, keyword_init: true)
    Edge = Struct.new(:from, :to, :kind, :label, keyword_init: true)

    class Graph
      attr_reader :nodes, :edges

      def initialize
        @nodes = []
        @edges = []
      end

      def add_node(id:, label:, kind:, group: nil)
        return if nodes.any? { |node| node.id == id }

        nodes << Node.new(id:, label:, kind:, group:)
      end

      def add_edge(from:, to:, kind:, label: nil)
        edge = Edge.new(from:, to:, kind:, label:)
        return if edges.include?(edge)

        edges << edge
      end

      def to_h
        {
          nodes: nodes.map { |node| { id: node.id, label: node.label, kind: node.kind, group: node.group } },
          edges: edges.map { |edge| { from: edge.from, to: edge.to, kind: edge.kind, label: edge.label } }
        }
      end

      def to_mermaid
        lines = ["flowchart TD"]
        grouped_nodes = nodes.group_by(&:group)

        grouped_nodes[nil].to_a.each { |node| lines << "  #{mermaid_node(node)}" }

        grouped_nodes.keys.compact.sort.each do |group|
          lines << "  subgraph #{sanitize_id(group)}[#{escape_label(group)}]"
          grouped_nodes[group].each { |node| lines << "    #{mermaid_node(node)}" }
          lines << "  end"
        end

        edges.each do |edge|
          connector = edge.kind == :data_flow ? "-.->" : "-->"
          label = edge.label ? "|#{escape_label(edge.label)}|" : nil
          lines << "  #{sanitize_id(edge.from)} #{connector}#{label} #{sanitize_id(edge.to)}"
        end

        lines.join("\n")
      end

      private

      def mermaid_node(node)
        shape_open, shape_close =
          case node.kind
          when :approval_step then ["{", "}"]
          when :tool_step, :agent_step, :workflow, :operation, :entrypoint, :trigger then ["[", "]"]
          else ["(", ")"]
          end

        %(#{sanitize_id(node.id)}#{shape_open}"#{escape_label(node.label)}"#{shape_close})
      end

      def sanitize_id(value)
        value.to_s.gsub(/[^a-zA-Z0-9_]/, "_")
      end

      def escape_label(value)
        value.to_s.gsub('"', '\"')
      end
    end

    class Builder
      def self.for_workflow(workflow_class)
        new.build_workflow(workflow_class)
      end

      def self.for_operation(operation_class)
        new.build_operation(operation_class)
      end

      def build_workflow(workflow_class, graph: Graph.new, group: workflow_class.name, prefix: workflow_class.name)
        workflow_id = node_id(prefix, :workflow)
        input_id = node_id(prefix, :input)
        context_id = node_id(prefix, :context)
        output_id = node_id(prefix, :output)

        graph.add_node(id: workflow_id, label: workflow_class.name.to_s, kind: :workflow, group:)
        graph.add_node(id: input_id, label: "workflow input", kind: :input, group:)
        graph.add_node(id: output_id, label: "workflow output", kind: :output, group:)

        graph.add_edge(from: workflow_id, to: input_id, kind: :structure)

        steps = workflow_class.rubot_steps
        output_keys = steps.each_with_object({}) do |step_definition, memo|
          memo[(step_definition.options[:save_as] || step_definition.name).to_sym] = step_definition
        end

        previous_id = input_id

        steps.each_with_index do |step_definition, index|
          step_id = node_id(prefix, step_definition.name)
          graph.add_node(
            id: step_id,
            label: "#{step_definition.name} (#{step_definition.kind})",
            kind: step_definition.kind,
            group:
          )

          label = sequence_label_for(step_definition)
          if step_definition.options[:if]
            label = "if: #{step_definition.options[:if].is_a?(Symbol) ? step_definition.options[:if] : '...'}"
          elsif step_definition.options[:unless]
            label = "unless: #{step_definition.options[:unless].is_a?(Symbol) ? step_definition.options[:unless] : '...'}"
          end

          graph.add_edge(from: previous_id, to: step_id, kind: :sequence, label: label)

          if step_definition.options[:if] || step_definition.options[:unless]
            next_step = steps[index + 1]
            next_id = next_step ? node_id(prefix, next_step.name) : output_id
            graph.add_edge(from: previous_id, to: next_id, kind: :sequence, label: "skip")
          end

          if (jump_target = step_definition.options[:jumps_to])
            Array(jump_target).each do |target|
              graph.add_edge(from: step_id, to: node_id(prefix, target), kind: :sequence, label: "jump")
            end
          end

          add_component_edge(graph, prefix:, step_definition:, step_id:, group:)
          data_sources_for(step_definition.options[:input]).each do |source|
            add_data_flow_edge(graph, source:, step_id:, context_id:, input_id:, output_keys:, prefix:)
          end
          previous_id = step_id
        end

        graph.add_edge(from: previous_id, to: output_id, kind: :sequence)
        graph
      end

      def build_operation(operation_class)
        graph = Graph.new
        operation_id = node_id(operation_class.name, :operation)
        group = operation_class.name.to_s

        graph.add_node(id: operation_id, label: operation_class.name.to_s, kind: :operation, group: nil)

        operation_class.entrypoints.each do |entrypoint|
          entrypoint_id = node_id(operation_class.name, "entrypoint_#{entrypoint.name}")
          graph.add_node(id: entrypoint_id, label: "entrypoint: #{entrypoint.name}", kind: :entrypoint, group: nil)
          graph.add_edge(from: entrypoint_id, to: operation_id, kind: :structure)

          workflow_name = entrypoint.options[:workflow]
          trigger_name = entrypoint.options[:trigger]

          graph.add_edge(from: entrypoint_id, to: workflow_reference_id(operation_class.name, workflow_name), kind: :structure, label: "workflow") if workflow_name
          graph.add_edge(from: entrypoint_id, to: node_id(operation_class.name, "trigger_#{trigger_name}"), kind: :structure, label: "trigger") if trigger_name
        end

        operation_class.triggers.each do |trigger|
          trigger_id = node_id(operation_class.name, "trigger_#{trigger.name}")
          graph.add_node(id: trigger_id, label: "trigger: #{trigger.name}", kind: :trigger, group: nil)
          graph.add_edge(from: trigger_id, to: operation_id, kind: :structure)

          workflow_name = trigger.options[:workflow]
          target_id = workflow_name ? workflow_reference_id(operation_class.name, workflow_name) : operation_id
          graph.add_edge(from: trigger_id, to: target_id, kind: :structure, label: "routes") if workflow_name
        end

        operation_class.send(:rubot_operation_workflows).each do |workflow_key, workflow_class|
          workflow_root_id = workflow_reference_id(operation_class.name, workflow_key)
          graph.add_node(id: workflow_root_id, label: "workflow: #{workflow_key}", kind: :workflow, group: nil)
          graph.add_edge(from: operation_id, to: workflow_root_id, kind: :structure)
          build_workflow(workflow_class, graph:, group:, prefix: "#{operation_class.name}_#{workflow_key}")
          graph.add_edge(from: workflow_root_id, to: node_id("#{operation_class.name}_#{workflow_key}", :workflow), kind: :structure)
        end

        graph
      end

      private

      def add_component_edge(graph, prefix:, step_definition:, step_id:, group:)
        component =
          case step_definition.kind
          when :tool_step then step_definition.options[:tool]
          when :agent_step then step_definition.options[:agent]
          else
            nil
          end
        return unless component

        component_id = node_id(prefix, "#{step_definition.name}_component")
        graph.add_node(id: component_id, label: component.name.to_s, kind: :component, group:)
        graph.add_edge(from: step_id, to: component_id, kind: :structure, label: "uses")
      end

      def add_data_flow_edge(graph, source:, step_id:, context_id:, input_id:, output_keys:, prefix:)
        case source[:source]
        when :input
          graph.add_edge(from: input_id, to: step_id, kind: :data_flow, label: source_label(source))
        when :context
          graph.add_node(id: context_id, label: "workflow context", kind: :context, group: source[:group])
          graph.add_edge(from: context_id, to: step_id, kind: :data_flow, label: source_label(source))
        when :state
          producer = output_keys[source[:key]]
          return unless producer

          graph.add_edge(from: node_id(prefix, producer.name), to: step_id, kind: :data_flow, label: source[:key].to_s)
        end
      end

      def source_label(source)
        return source[:key].to_s if source[:key]

        source[:source].to_s
      end

      def sequence_label_for(step_definition)
        step_definition.kind == :approval_step ? "resume" : nil
      end

      def data_sources_for(input_option)
        case input_option
        when Symbol
          [{ source: :state, key: input_option.to_sym }]
        when Rubot::Workflow::InputMapping
          mapping_sources(input_option.metadata)
        else
          []
        end
      end

      def mapping_sources(metadata)
        return [] unless metadata.is_a?(Hash)

        case metadata[:kind]
        when :source
          if metadata[:source] == :state && metadata[:keys]&.length == 1
            [{ source: :state, key: metadata[:keys].first.to_sym }]
          elsif metadata[:source] == :input && metadata[:keys]&.length == 1
            [{ source: :input, key: metadata[:keys].first.to_sym }]
          elsif metadata[:source] == :context && metadata[:keys]&.length == 1
            [{ source: :context, key: metadata[:keys].first.to_sym }]
          elsif metadata[:source] == :input && metadata[:keys].nil?
            [{ source: :input }]
          elsif metadata[:source] == :context && metadata[:keys].nil?
            [{ source: :context }]
          else
            []
          end
        when :slice
          mapping_sources(metadata[:source])
        when :merge
          Array(metadata[:sources]).flat_map { |item| mapping_sources(item) }
        else
          []
        end
      end

      def node_id(prefix, name)
        "#{prefix}_#{name}"
      end

      def workflow_reference_id(prefix, workflow_key)
        node_id(prefix, "workflow_ref_#{workflow_key}")
      end
    end
  end
end
