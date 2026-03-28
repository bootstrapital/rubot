# frozen_string_literal: true

module Rubot
  module DSL
    UNSET = Object.new

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
      subclass.instance_variable_set(:@rubot_tags, @rubot_tags&.dup)
      subclass.instance_variable_set(:@rubot_metadata, @rubot_metadata&.dup)
      subclass.instance_variable_set(:@rubot_config_file_path, @rubot_config_file_path)
      subclass.instance_variable_set(:@rubot_middlewares, rubot_middlewares.dup)
      subclass.instance_variable_set(:@rubot_playground_fixtures, rubot_playground_fixtures.dup)
    end

    def discover
      {
        name: name,
        description: description,
        input_schema: input_schema.to_json_schema,
        output_schema: output_schema.to_json_schema,
        tags: tags,
        metadata: metadata
      }.compact
    end

    def instructions(value = UNSET, &block)
      return resolved_agent_config_value(:instructions, @rubot_instructions) if value.equal?(UNSET) && !block

      @rubot_instructions = block || value
    end

    def description(text = UNSET)
      return resolved_agent_config_value(:description, @rubot_description) if text.equal?(UNSET)

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

    def model(name = UNSET)
      return resolved_agent_config_value(:model, @rubot_model_name) if name.equal?(UNSET)

      @rubot_model_name = name
    end

    def tags(*values)
      return resolved_agent_config_value(:tags, @rubot_tags) if values.empty?

      @rubot_tags = values.flatten.map(&:to_s).freeze
    end

    def metadata(values = UNSET)
      return resolved_agent_config_value(:metadata, @rubot_metadata) if values.equal?(UNSET)

      raise Rubot::ValidationError, "Rubot metadata must be a mapping" unless values.is_a?(Hash)

      @rubot_metadata = Rubot::HashUtils.symbolize(values).freeze
    end

    def config_file(path = UNSET)
      return @rubot_config_file_path if path.equal?(UNSET)

      @rubot_config_file_path = path
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

    def resolved_config_file
      explicit = @rubot_config_file_path
      return expand_config_file_path(explicit) if explicit

      inferred = inferred_config_file_path
      inferred if inferred && File.exist?(inferred)
    end

    def agent_config
      Rubot::AgentConfigFile.load(path: resolved_config_file)
    end

    private

    def resolved_agent_config_value(key, explicit_value)
      return explicit_value unless explicit_value.nil?

      agent_config[key]
    end

    def inferred_config_file_path
      source_path = const_source_location(name)&.first
      return unless source_path

      File.join(File.dirname(source_path), "#{File.basename(source_path, '.rb')}.yml")
    end

    def expand_config_file_path(path)
      source_path = const_source_location(name)&.first
      base_dir = source_path ? File.dirname(source_path) : Dir.pwd
      File.expand_path(path.to_s, base_dir)
    end
  end
end
