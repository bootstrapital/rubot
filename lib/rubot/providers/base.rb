# frozen_string_literal: true

module Rubot
  module Providers
    class Base
      def complete(_messages:, _tools: [], _output_schema: nil, **_options)
        raise NotImplementedError, "#{self.class.name} must implement #complete"
      end

      private

      def symbolize_hash(value)
        case value
        when Array
          value.map { |item| symbolize_hash(item) }
        when Hash
          value.each_with_object({}) do |(key, nested_value), memo|
            memo[key.respond_to?(:to_sym) ? key.to_sym : key] = symbolize_hash(nested_value)
          end
        else
          value
        end
      end
    end
  end
end
