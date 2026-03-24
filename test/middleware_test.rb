# frozen_string_literal: true

require_relative "test_helper"

class DenyUnlessAuthorized < Rubot::Middleware::Authorization
  def authorize!(env)
    return if env[:context][:authorized]

    raise Rubot::AuthorizationError, "not authorized"
  end
end

class RedactSecretMessages < Rubot::Middleware::Guardrail
  def guard_input(input, _env)
    return input unless input[:secret]

    input.merge(secret: "[FILTERED]")
  end

  def guard_messages(messages, _env)
    Array(messages).map do |message|
      next message unless message[:content].is_a?(String)

      message.merge(content: message[:content].gsub("top-secret", "[FILTERED]"))
    end
  end
end

class MiddlewareProvider
  attr_reader :messages

  def complete(messages:, tools:, output_schema:, model:)
    @messages = messages

    Rubot::Providers::Result.new(
      provider: "test",
      model: model || "middleware-model",
      content: "",
      output: { summary: messages.last[:content] },
      tool_calls: [],
      usage: {},
      finish_reason: "stop"
    )
  end
end

class MiddlewareAgent < Rubot::Agent
  use DenyUnlessAuthorized
  use RedactSecretMessages

  input_schema do
    string :secret
  end

  output_schema do
    string :summary
  end
end

class MiddlewareTest < Minitest::Test
  def setup
    @provider = MiddlewareProvider.new

    Rubot.configure do |config|
      config.provider = @provider
    end
  end

  def test_authorization_middleware_blocks_agent_execution
    error = assert_raises(Rubot::AuthorizationError) do
      Rubot.run(MiddlewareAgent, input: { secret: "top-secret" }, context: { authorized: false })
    end

    assert_equal "not authorized", error.message
  end

  def test_guardrail_middleware_redacts_provider_bound_content
    run = Rubot.run(MiddlewareAgent, input: { secret: "top-secret" }, context: { authorized: true })

    assert_equal :completed, run.status
    assert_equal "{\"input\":{\"secret\":\"[FILTERED]\"},\"context\":{\"authorized\":true}}", @provider.messages.last[:content]
  end
end
