# frozen_string_literal: true

module Rubot
  class Error < StandardError; end
  class ValidationError < Error; end
  class ExecutionError < Error; end
  class AuthorizationError < ExecutionError; end
  class GuardrailError < ExecutionError; end
  class RetryableError < ExecutionError
    attr_reader :category, :details

    def initialize(message = nil, category: :runtime, details: {})
      super(message)
      @category = category
      @details = details
    end
  end
  class ConcurrencyError < RetryableError
    def initialize(message = "Concurrent execution conflict", **options)
      super(message, category: :concurrency, **options)
    end
  end
  class HTTPError < ExecutionError
    attr_reader :status, :headers, :body, :details

    def initialize(message = "HTTP request failed", status: nil, headers: {}, body: nil, details: {})
      super(message)
      @status = status
      @headers = headers
      @body = body
      @details = details
    end
  end
  class MCPError < ExecutionError
    attr_reader :details

    def initialize(message = "MCP tool call failed", details: {})
      super(message)
      @details = details
    end
  end
  class CancellationError < ExecutionError; end
  class ApprovalRequired < Error; end
end
