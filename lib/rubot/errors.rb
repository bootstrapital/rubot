# frozen_string_literal: true

module Rubot
  class Error < StandardError; end
  class ValidationError < Error; end
  class ExecutionError < Error; end
  class AuthorizationError < ExecutionError; end
  class GuardrailError < ExecutionError; end
  class ApprovalRequired < Error; end
end
