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
      subclass.instance_variable_set(:@rubot_memory_adapter, @rubot_memory_adapter)
      subclass.instance_variable_set(:@rubot_provider_adapter, @rubot_provider_adapter)
      subclass.instance_variable_set(:@rubot_model_name, @rubot_model_name)
      subclass.instance_variable_set(:@rubot_middlewares, rubot_middlewares.dup)
    end

    def instructions(&block)
      return @rubot_instructions unless block

      @rubot_instructions = block.call
    end

    def description(text = nil)
      return @rubot_description if text.nil?

      @rubot_description = text
    end

    def tools(*tool_classes)
      @rubot_tools ||= []
      @rubot_tools.concat(tool_classes) unless tool_classes.empty?
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

    def memory(adapter = nil)
      return @rubot_memory_adapter if adapter.nil?

      @rubot_memory_adapter = adapter
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
  end
end
