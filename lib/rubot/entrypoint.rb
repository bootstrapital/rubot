# frozen_string_literal: true

module Rubot
  class EntryPoint
    attr_reader :name, :options

    def initialize(name:, **options)
      @name = name.to_sym
      @options = options
    end

    def resolve(payload:, subject:, context:, operation:)
      base =
        if options[:trigger]
          operation.resolve_launch(trigger: options[:trigger], payload:, subject:, context:)
        else
          { input: payload, subject: subject, context: context, workflow: options[:workflow] }
        end

      resolved_payload = resolve_value(options[:input], payload: base[:input], subject: base[:subject], context: base[:context], operation:) || base[:input]
      resolved_subject = resolve_value(options[:subject], payload: resolved_payload, subject: base[:subject], context: base[:context], operation:) || base[:subject]
      resolved_context = resolve_context(payload: resolved_payload, subject: resolved_subject, context: base[:context], operation:)
      resolved_workflow = resolve_value(options[:workflow], payload: resolved_payload, subject: resolved_subject, context: resolved_context, operation:) || base[:workflow]

      {
        input: resolved_payload,
        subject: resolved_subject,
        context: resolved_context,
        workflow: resolved_workflow
      }
    end

    private

    def resolve_context(payload:, subject:, context:, operation:)
      addition = resolve_value(options[:context], payload: payload, subject: subject, context: context, operation:)
      return context unless addition

      context.merge(addition)
    end

    def resolve_value(value, payload:, subject:, context:, operation:)
      case value
      when Proc
        operation.instance_exec(payload, subject, context, &value)
      else
        value
      end
    end
  end
end
