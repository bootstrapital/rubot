# frozen_string_literal: true

require_relative "support_triage_agent"

module Examples
  module YamlPromptEval
    class SupportWorkflow < Rubot::Workflow
      agent_step :triage, agent: SupportTriageAgent
    end

    class SupportOperation < Rubot::Operation
      workflow SupportWorkflow
    end
  end
end
