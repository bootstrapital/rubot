# frozen_string_literal: true

module Rubot
  module Playground
    class Registry
      SUPERCLASSES = {
        tool: Rubot::Tool,
        agent: Rubot::Agent,
        workflow: Rubot::Workflow
      }.freeze

      def classes(kind)
        superclass = SUPERCLASSES.fetch(kind.to_sym)

        ObjectSpace.each_object(Class).select do |klass|
          klass < superclass && klass.name
        end.sort_by(&:name)
      end

      def resolve(kind, class_name)
        classes(kind).find { |klass| klass.name == class_name.to_s } ||
          raise(Rubot::ExecutionError, "Unable to resolve #{kind} #{class_name}")
      end
    end

    class FixtureSet
      def initialize(runnable)
        @runnable = runnable
      end

      attr_reader :runnable

      def options
        fixtures = runnable.respond_to?(:rubot_playground_fixtures) ? runnable.rubot_playground_fixtures : []
        resolved = fixtures.map { |fixture| resolve_fixture(fixture) }
        resolved << default_fixture if resolved.empty?
        resolved
      end

      private

      def resolve_fixture(fixture)
        dynamic = fixture[:block] ? runnable.instance_exec(&fixture[:block]) : {}
        resolved = Rubot::HashUtils.symbolize(dynamic || {})

        {
          name: fixture[:name],
          input: resolved.key?(:input) ? resolved[:input] : (fixture[:input] || sample_from_schema(runnable.input_schema)),
          context: resolved.key?(:context) ? resolved[:context] : (fixture[:context] || {}),
          subject: resolved.key?(:subject) ? resolved[:subject] : fixture[:subject]
        }
      end

      def default_fixture
        {
          name: :blank,
          input: sample_from_schema(runnable.input_schema),
          context: {},
          subject: nil
        }
      end

      def sample_from_schema(schema)
        return {} unless schema.respond_to?(:fields)

        schema.fields.each_with_object({}) do |field, memo|
          memo[field.name] = sample_for_field(field)
        end
      end

      def sample_for_field(field)
        case field.type
        when :string
          "#{field.name}_sample"
        when :integer
          1
        when :float
          1.0
        when :boolean
          false
        when :array
          [sample_for_item(field.item_type, field.name)]
        else
          nil
        end
      end

      def sample_for_item(item_type, name)
        case item_type
        when :string
          "#{name}_item"
        when :integer
          1
        when :float
          1.0
        when :boolean
          false
        else
          nil
        end
      end
    end

    class Invocation
      def call(kind:, runnable:, input:, context: {}, subject: nil)
        case kind.to_sym
        when :tool
          execute_tool(runnable, input:, context:, subject:)
        when :agent, :workflow
          Rubot.run(runnable, input:, context:, subject:)
        else
          raise Rubot::ExecutionError, "Unsupported playground kind #{kind}"
        end
      end

      private

      def execute_tool(runnable, input:, context:, subject:)
        run = Rubot::Run.new(name: runnable.name, kind: :tool, input:, context:, subject:, persist: false)
        run.define_singleton_method(:persist!) { self }
        run.add_event(Event.new(type: "run.started", payload: { name: run.name, kind: run.kind, input: run.input, subject: run.subject }))
        run.start!
        output = runnable.new.execute(input:, run:)
        run.complete!(output)
        run.add_event(Event.new(type: "run.completed", payload: { output: run.output }))
        run
      rescue StandardError => e
        unless run.failed?
          run.fail!(class: e.class.name, message: e.message)
          run.add_event(Event.new(type: "run.failed", payload: { error_class: e.class.name, error_message: e.message }))
        end
        raise
      end
    end
  end
end
