# frozen_string_literal: true

module Rubot
  class Trigger
    attr_reader :kind, :name, :options

    def initialize(kind:, name: kind, **options)
      @kind = kind.to_sym
      @name = name.to_sym
      @options = options
    end

    def resolve(payload:, subject:, context:, operation:)
      {
        input: resolve_value(options[:input], payload:, subject:, context:, operation:) || payload,
        subject: resolve_value(options[:subject], payload:, subject:, context:, operation:) || subject,
        context: resolved_context(payload:, subject:, context:, operation:)
      }
    end

    private

    def resolved_context(payload:, subject:, context:, operation:)
      addition = resolve_value(options[:context], payload:, subject:, context:, operation:)
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
