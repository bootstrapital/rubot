# frozen_string_literal: true

module ProcessOpsExamples
  module Sipoc
    class Workflow < Rubot::Workflow
      tool_step :load_process_brief,
                tool: ProcessOpsExamples::Sipoc::LoadProcessBriefTool,
                input: lambda { |input, _state, _context|
                  {
                    process_name: input[:process_name],
                    stakeholders: input[:stakeholders],
                    artifacts: input[:artifacts],
                    notes: input[:notes]
                  }
                }

      agent_step :draft_sipoc,
                 agent: ProcessOpsExamples::Sipoc::DraftSipocAgent,
                 input: ->(_input, state, _context) { state.fetch(:load_process_brief) }

      approval_step :facilitator_review,
                    role: "process_owner",
                    reason: "Approve the initial SIPOC frame before deeper mapping."

      step :finalize

      def finalize
        run.state[:finalize] = {
          sipoc: run.state.fetch(:draft_sipoc),
          review: run.approvals.last&.decision_payload
        }
      end
    end
  end
end
