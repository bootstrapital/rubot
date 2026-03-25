# frozen_string_literal: true

module Rubot
  module Providers
    class Base
      def complete(_messages:, _tools: [], _output_schema: nil, **_options)
        raise NotImplementedError, "#{self.class.name} must implement #complete"
      end

    end
  end
end
