# frozen_string_literal: true

module Rubot
  class AgentResolutionContext
    attr_reader :agent, :run, :input, :context

    def initialize(agent:, run:, input:, context:)
      @agent = agent
      @run = run
      @input = input
      @context = context
    end

    def subject
      run.subject
    end

    def current_step
      run.current_step
    end
  end
end
