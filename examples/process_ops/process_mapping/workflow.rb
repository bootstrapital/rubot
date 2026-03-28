# frozen_string_literal: true

module ProcessOpsExamples
  module ProcessMapping
    class Workflow < Rubot::Workflow
      tool_step :collect_process_evidence,
                tool: ProcessOpsExamples::ProcessMapping::CollectProcessEvidenceTool,
                input: lambda { |input, _state, _context|
                  {
                    process_name: input[:process_name],
                    systems: input[:systems],
                    actors: input[:actors],
                    known_steps: input[:known_steps],
                    known_exceptions: input[:known_exceptions]
                  }
                }

      agent_step :draft_current_state_map,
                 agent: ProcessOpsExamples::ProcessMapping::DraftCurrentStateMapAgent,
                 input: ->(_input, state, _context) { state.fetch(:collect_process_evidence) }

      approval_step :owner_review,
                    role: "process_owner",
                    reason: "Review the draft current-state map for accuracy."

      step :finalize

      def finalize
        run.state[:finalize] = {
          current_state_map: run.state.fetch(:draft_current_state_map),
          review: run.approvals.last&.decision_payload
        }
      end
    end
  end
end
