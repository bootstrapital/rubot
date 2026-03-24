# frozen_string_literal: true

module Rubot
  module Providers
    class Result
      attr_reader :content, :output, :tool_calls, :usage, :finish_reason, :model, :provider, :raw

      def initialize(content: nil, output: nil, tool_calls: [], usage: nil, finish_reason: nil, model: nil, provider: nil, raw: nil)
        @content = content
        @output = output
        @tool_calls = tool_calls
        @usage = usage
        @finish_reason = finish_reason
        @model = model
        @provider = provider
        @raw = raw
      end

      def to_h
        {
          content: content,
          output: output,
          tool_calls: tool_calls,
          usage: usage,
          finish_reason: finish_reason,
          model: model,
          provider: provider
        }
      end
    end
  end
end
