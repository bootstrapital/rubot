# frozen_string_literal: true

module Rubot
  # Provisional API: Rubot::Operation is the intended feature boundary,
  # but its authoring surface may still tighten during v0.2.
  class Operation
    extend DSL

    class << self
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@rubot_operation_workflow, @rubot_operation_workflow)
        subclass.instance_variable_set(:@rubot_operation_agent, @rubot_operation_agent)
        subclass.instance_variable_set(:@rubot_operation_workflows, (rubot_operation_workflows || {}).dup)
        subclass.instance_variable_set(:@rubot_operation_agents, (rubot_operation_agents || {}).dup)
        subclass.instance_variable_set(:@rubot_operation_default_workflow_key, @rubot_operation_default_workflow_key)
        subclass.instance_variable_set(:@rubot_operation_default_agent_key, @rubot_operation_default_agent_key)
        subclass.instance_variable_set(:@rubot_operation_tools, (rubot_operation_tools || {}).dup)
        subclass.instance_variable_set(:@rubot_operation_triggers, rubot_operation_triggers.dup)
        subclass.instance_variable_set(:@rubot_operation_entrypoints, rubot_operation_entrypoints.dup)
        subclass.instance_variable_set(:@rubot_operation_ui, @rubot_operation_ui)
        subclass.instance_variable_set(:@rubot_operation_memory_config, (@rubot_operation_memory_config&.dup || Rubot::Memory::Config.new))
      end

      def workflow(identifier = nil, klass = nil, name: nil, default: false, &block)
        return lookup_workflow(identifier) unless definitional_component?(identifier, klass, block)

        klass, identifier = extract_component_args(identifier, klass)

        component_name = name || default_workflow_name(identifier)
        component = define_component(klass, name: component_name, superclass: Rubot::Workflow, &block)
        register_workflow(identifier, component, default:)
      end

      def workflows
        rubot_operation_workflows.values
      end

      def discover
        {
          name: name,
          workflows: rubot_operation_workflows.transform_values(&:discover),
          agents: rubot_operation_agents.transform_values(&:discover),
          tools: rubot_operation_tools.transform_values(&:discover),
          entrypoints: rubot_operation_entrypoints.transform_values(&:options)
        }.compact
      end

      def flow_graph
        Rubot::FlowVisualization::Builder.for_operation(self)
      end

      def flow_mermaid
        flow_graph.to_mermaid
      end

      def agent(identifier = nil, klass = nil, name: nil, default: false, &block)
        return lookup_agent(identifier) unless definitional_component?(identifier, klass, block)

        klass, identifier = extract_component_args(identifier, klass)

        component_name = name || default_agent_name(identifier)
        component = define_component(klass, name: component_name, superclass: Rubot::Agent, &block)
        register_agent(identifier, component, default:)
      end

      def agents
        rubot_operation_agents.values
      end

      def tool(identifier = nil, klass = nil, name: nil, &block)
        registry = rubot_operation_tools

        return registry[identifier] if identifier.is_a?(Symbol) && klass.nil? && !block

        component =
          if block
            component_name = name || default_tool_name(identifier)
            define_component(klass, name: component_name, superclass: Rubot::Tool, &block)
          else
            klass || identifier
          end

        key = identifier.is_a?(Symbol) ? identifier : normalize_tool_key(component.name.split("::").last.sub(/Tool\z/, ""))
        registry[key] = component
        component
      end

      def tools
        rubot_operation_tools.values
      end

      def trigger(kind, name: kind, **options)
        rubot_operation_triggers << Trigger.new(kind:, name:, **options)
      end

      def triggers
        rubot_operation_triggers
      end

      def entrypoint(name, **options)
        definition = EntryPoint.new(name:, **options)
        rubot_operation_entrypoints[definition.name] = definition
        define_entrypoint_helpers(definition.name)
        definition
      end

      def entrypoints
        rubot_operation_entrypoints.values
      end

      def ui(config = nil, &block)
        @rubot_operation_ui = config || block if config || block
        @rubot_operation_ui
      end

      def memory(&block)
        @rubot_operation_memory_config ||= Rubot::Memory::Config.new
        return @rubot_operation_memory_config unless block

        @rubot_operation_memory_config.instance_eval(&block)
        @rubot_operation_memory_config
      end

      def launch(payload: {}, subject: nil, context: {}, trigger: nil, workflow: nil, entrypoint: nil)
        resolved = resolve_operation_launch(entrypoint:, workflow:, trigger:, payload:, subject:, context:)
        Rubot.run(resolve_runnable(workflow || resolved[:workflow]), input: resolved[:input], subject: resolved[:subject], context: resolved[:context])
      end

      def launch_for(subject, payload: {}, context: {}, trigger: nil, workflow: nil, entrypoint: nil)
        launch(payload:, subject:, context:, trigger:, workflow:, entrypoint:)
      end

      def enqueue(payload: {}, subject: nil, context: {}, trigger: nil, workflow: nil, entrypoint: nil)
        resolved = resolve_operation_launch(entrypoint:, workflow:, trigger:, payload:, subject:, context:)
        Rubot.enqueue(resolve_runnable(workflow || resolved[:workflow]), input: resolved[:input], subject: resolved[:subject], context: resolved[:context])
      end

      def enqueue_for(subject, payload: {}, context: {}, trigger: nil, workflow: nil, entrypoint: nil)
        enqueue(payload:, subject:, context:, trigger:, workflow:, entrypoint:)
      end

      def runnable(workflow_name = nil)
        resolve_runnable(workflow_name)
      end

      def find_trigger(name)
        return Trigger.new(kind: :manual) if name.nil? && triggers.empty?

        triggers.find { |trigger_definition| trigger_definition.name == (name || :manual).to_sym } ||
          raise(ExecutionError, "#{self.name} does not define trigger #{name || :manual}")
      end

      def resolve_launch(trigger:, payload:, subject:, context:)
        find_trigger(trigger).resolve(payload:, subject:, context:, operation: self)
      end

      private

      def resolve_operation_launch(entrypoint:, workflow:, trigger:, payload:, subject:, context:)
        if entrypoint
          raise ValidationError, "Operation launch cannot combine entrypoint with workflow or trigger" if workflow || trigger

          return find_entrypoint(entrypoint).resolve(payload:, subject:, context:, operation: self)
        end

        return { input: payload, subject: subject, context: context, workflow: workflow } if workflow && trigger.nil?

        resolve_launch(trigger:, payload:, subject:, context:)
      end

      def resolve_runnable(workflow_name = nil)
        workflow(workflow_name) || agent || raise(ExecutionError, "#{name} must define a workflow or agent")
      end

      def rubot_operation_workflows
        @rubot_operation_workflows ||= {}
      end

      def rubot_operation_agents
        @rubot_operation_agents ||= {}
      end

      def rubot_operation_tools
        @rubot_operation_tools ||= {}
      end

      def rubot_operation_triggers
        @rubot_operation_triggers ||= []
      end

      def rubot_operation_entrypoints
        @rubot_operation_entrypoints ||= {}
      end

      def find_entrypoint(name)
        rubot_operation_entrypoints[name.to_sym] ||
          raise(ExecutionError, "#{self.name} does not define entrypoint #{name}")
      end

      def define_entrypoint_helpers(name)
        define_singleton_method("launch_#{name}") do |payload: {}, subject: nil, context: {}|
          launch(payload:, subject:, context:, entrypoint: name)
        end

        define_singleton_method("launch_#{name}_for") do |subject, payload: {}, context: {}|
          launch_for(subject, payload:, context:, entrypoint: name)
        end

        define_singleton_method("enqueue_#{name}") do |payload: {}, subject: nil, context: {}|
          enqueue(payload:, subject:, context:, entrypoint: name)
        end

        define_singleton_method("enqueue_#{name}_for") do |subject, payload: {}, context: {}|
          enqueue_for(subject, payload:, context:, entrypoint: name)
        end
      end

      def define_component(klass, name:, superclass:, &block)
        component =
          if klass
            klass
          else
            const_name = name.to_s
            if const_defined?(const_name, false)
              const_get(const_name, false)
            else
              const_set(const_name, Class.new(superclass))
            end
          end

        apply_operation_owner(component, superclass)
        component.class_eval(&block) if block
        apply_operation_defaults(component, superclass)
        component
      end

      def apply_operation_owner(component, superclass)
        return unless superclass == Rubot::Workflow || superclass == Rubot::Agent

        component.instance_variable_set(:@rubot_operation_owner, self)
      end

      def apply_operation_defaults(component, superclass)
        return unless superclass == Rubot::Agent
        return if memory.empty? || !component.rubot_memory_config.empty?

        component.instance_variable_set(:@rubot_memory_config, memory.dup)
      end

      def register_workflow(identifier, component, default:)
        key = normalize_workflow_key(identifier, component)
        rubot_operation_workflows[key] = component
        @rubot_operation_default_workflow_key = key if default || @rubot_operation_default_workflow_key.nil?
        @rubot_operation_workflow = rubot_operation_workflows.fetch(@rubot_operation_default_workflow_key)
        component
      end

      def register_agent(identifier, component, default:)
        key = normalize_agent_key(identifier, component)
        rubot_operation_agents[key] = component
        @rubot_operation_default_agent_key = key if default || @rubot_operation_default_agent_key.nil?
        @rubot_operation_agent = rubot_operation_agents.fetch(@rubot_operation_default_agent_key)
        component
      end

      def lookup_workflow(identifier)
        return @rubot_operation_workflow if identifier.nil?

        rubot_operation_workflows[identifier.to_sym]
      end

      def lookup_agent(identifier)
        return @rubot_operation_agent if identifier.nil?

        rubot_operation_agents[identifier.to_sym]
      end

      def definitional_component?(identifier, klass, block)
        !!(klass || block || identifier.is_a?(Class))
      end

      def extract_component_args(identifier, klass)
        return [identifier, nil] if klass.nil? && identifier.is_a?(Class)

        [klass, identifier]
      end

      def normalize_workflow_key(identifier, component)
        return identifier.to_sym if identifier.is_a?(Symbol)

        normalize_tool_key(component.name.split("::").last.sub(/Workflow\z/, ""))
      end

      def normalize_agent_key(identifier, component)
        return identifier.to_sym if identifier.is_a?(Symbol)

        normalize_tool_key(component.name.split("::").last.sub(/Agent\z/, ""))
      end

      def default_workflow_name(identifier)
        return "Workflow" unless identifier.is_a?(Symbol)

        "#{camelize(identifier.to_s)}Workflow"
      end

      def default_agent_name(identifier)
        return "Agent" unless identifier.is_a?(Symbol)

        "#{camelize(identifier.to_s)}Agent"
      end

      def default_tool_name(identifier)
        stem = identifier.is_a?(Symbol) ? camelize(identifier.to_s) : "Tool"
        "#{stem}Tool"
      end

      def camelize(value)
        value.split("_").map(&:capitalize).join
      end

      def normalize_tool_key(value)
        value.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym
      end
    end
  end
end
