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
  class CancellationError < ExecutionError; end
  class ApprovalRequired < Error; end
end
