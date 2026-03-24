# frozen_string_literal: true

module Rubot
  module DSL
    def inherited(subclass)
      super
      subclass.instance_variable_set(:@rubot_tools, rubot_tools.dup)
      subclass.instance_variable_set(:@rubot_steps, rubot_steps.dup)
      subclass.instance_variable_set(:@rubot_before_run_hooks, rubot_before_run_hooks.dup)
      subclass.instance_variable_set(:@rubot_after_run_hooks, rubot_after_run_hooks.dup)
      subclass.instance_variable_set(:@rubot_instructions, @rubot_instructions)
      subclass.instance_variable_set(:@rubot_description, @rubot_description)
      subclass.instance_variable_set(:@rubot_input_schema, @rubot_input_schema)
      subclass.instance_variable_set(:@rubot_output_schema, @rubot_output_schema)
      subclass.instance_variable_set(:@rubot_policy, @rubot_policy)
      subclass.instance_variable_set(:@rubot_memory_config, (@rubot_memory_config&.dup || Rubot::Memory::Config.new))
      subclass.instance_variable_set(:@rubot_provider_adapter, @rubot_provider_adapter)
      subclass.instance_variable_set(:@rubot_model_name, @rubot_model_name)
      subclass.instance_variable_set(:@rubot_middlewares, rubot_middlewares.dup)
      subclass.instance_variable_set(:@rubot_playground_fixtures, rubot_playground_fixtures.dup)
    end

    def instructions(value = nil, &block)
      return @rubot_instructions if value.nil? && !block

      @rubot_instructions = value || block
    end

    def description(text = nil)
      return @rubot_description if text.nil?

      @rubot_description = text
    end

    def tools(*tool_classes, &block)
      @rubot_tools ||= []
      if block
        @rubot_dynamic_tools = block
      elsif tool_classes.length == 1 && tool_classes.first.is_a?(Proc)
        @rubot_dynamic_tools = tool_classes.first
      elsif !tool_classes.empty?
        @rubot_tools.concat(tool_classes)
      end
      @rubot_tools
    end

    def input_schema(&block)
      return @rubot_input_schema || Schema.new unless block

      @rubot_input_schema = Schema.build(&block)
    end

    def output_schema(&block)
      return @rubot_output_schema || Schema.new unless block

      @rubot_output_schema = Schema.build(&block)
    end

    def before_run(method_name = nil, &block)
      @rubot_before_run_hooks ||= []
      @rubot_before_run_hooks << (method_name || block)
    end

    def after_run(method_name = nil, &block)
      @rubot_after_run_hooks ||= []
      @rubot_after_run_hooks << (method_name || block)
    end

    def policy(policy_name = nil, &block)
      return @rubot_policy if policy_name.nil? && !block

      @rubot_policy = policy_name || block
    end

    def rubot_policy
      @rubot_policy
    end

    def memory(&block)
      @rubot_memory_config ||= Rubot::Memory::Config.new
      return @rubot_memory_config unless block

      @rubot_memory_config.instance_eval(&block)
      @rubot_memory_config
    end

    def provider(adapter = nil)
      return @rubot_provider_adapter if adapter.nil?

      @rubot_provider_adapter = adapter
    end

    def model(name = nil)
      return @rubot_model_name if name.nil?

      @rubot_model_name = name
    end

    def use(middleware_class, **options)
      @rubot_middlewares ||= []
      @rubot_middlewares << { middleware: middleware_class, options: options }
    end

    def rubot_tools
      @rubot_tools ||= []
    end

    def rubot_steps
      @rubot_steps ||= []
    end

    def rubot_before_run_hooks
      @rubot_before_run_hooks ||= []
    end

    def rubot_after_run_hooks
      @rubot_after_run_hooks ||= []
    end

    def rubot_middlewares
      @rubot_middlewares ||= []
    end

    def rubot_memory_config
      @rubot_memory_config ||= Rubot::Memory::Config.new
    end

    def rubot_dynamic_tools
      @rubot_dynamic_tools
    end

    def playground_fixture(name, input: nil, context: {}, subject: nil, &block)
      @rubot_playground_fixtures ||= []
      @rubot_playground_fixtures << {
        name: name.to_sym,
        input: input,
        context: context,
        subject: subject,
        block: block
      }
    end

    def rubot_playground_fixtures
      @rubot_playground_fixtures ||= []
    end
  end
end
