# frozen_string_literal: true

module Rubot
  # Provisional API: Rubot::Operation is the intended feature boundary,
  # but its authoring surface may still tighten during v0.2.
  class Operation
    class << self
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@rubot_operation_workflow, @rubot_operation_workflow)
        subclass.instance_variable_set(:@rubot_operation_agent, @rubot_operation_agent)
        subclass.instance_variable_set(:@rubot_operation_tools, (rubot_operation_tools || {}).dup)
        subclass.instance_variable_set(:@rubot_operation_triggers, rubot_operation_triggers.dup)
        subclass.instance_variable_set(:@rubot_operation_ui, @rubot_operation_ui)
        subclass.instance_variable_set(:@rubot_operation_memory_config, (@rubot_operation_memory_config&.dup || Rubot::Memory::Config.new))
      end

      def workflow(klass = nil, name: "Workflow", &block)
        @rubot_operation_workflow = define_component(klass, name:, superclass: Rubot::Workflow, &block) if klass || block
        @rubot_operation_workflow
      end

      def agent(klass = nil, name: "Agent", &block)
        @rubot_operation_agent = define_component(klass, name:, superclass: Rubot::Agent, &block) if klass || block
        @rubot_operation_agent
      end

      def tool(identifier = nil, klass = nil, name: nil, &block)
        registry = rubot_operation_tools

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

      def launch(payload: {}, subject: nil, context: {}, trigger: nil)
        resolved = resolve_launch(trigger:, payload:, subject:, context:)
        Rubot.run(runnable, input: resolved[:input], subject: resolved[:subject], context: resolved[:context])
      end

      def launch_for(subject, payload: {}, context: {}, trigger: nil)
        launch(payload:, subject:, context:, trigger:)
      end

      def enqueue(payload: {}, subject: nil, context: {}, trigger: nil)
        resolved = resolve_launch(trigger:, payload:, subject:, context:)
        Rubot.enqueue(runnable, input: resolved[:input], subject: resolved[:subject], context: resolved[:context])
      end

      def enqueue_for(subject, payload: {}, context: {}, trigger: nil)
        enqueue(payload:, subject:, context:, trigger:)
      end

      def runnable
        workflow || agent || raise(ExecutionError, "#{name} must define a workflow or agent")
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

      def rubot_operation_tools
        @rubot_operation_tools ||= {}
      end

      def rubot_operation_triggers
        @rubot_operation_triggers ||= []
      end

      def define_component(klass, name:, superclass:, &block)
        return klass if klass

        const_name = name.to_s
        component =
          if const_defined?(const_name, false)
            const_get(const_name, false)
          else
            const_set(const_name, Class.new(superclass))
          end

        component.class_eval(&block) if block
        apply_operation_defaults(component, superclass)
        component
      end

      def apply_operation_defaults(component, superclass)
        return unless superclass == Rubot::Agent
        return if memory.empty? || !component.rubot_memory_config.empty?

        component.instance_variable_set(:@rubot_memory_config, memory.dup)
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
