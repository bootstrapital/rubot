# frozen_string_literal: true

module ProcessOpsExamples
  module ProcessImprovementProgram
    class CurrentStateWorkflow < Rubot::Workflow
      tool_step :load_program_brief,
                tool: ProcessOpsExamples::ProcessImprovementProgram::LoadProgramBriefTool,
                input: lambda { |input, _state, _context|
                  {
                    process_name: input[:process_name],
                    stakeholders: input[:stakeholders],
                    systems: input[:systems],
                    known_steps: input[:known_steps],
                    pain_points: input[:pain_points],
                    constraints: input[:constraints]
                  }
                }

      agent_step :draft_current_state,
                 agent: ProcessOpsExamples::ProcessImprovementProgram::DraftCurrentStateAgent,
                 input: ->(_input, state, _context) { state.fetch(:load_program_brief) }

      approval_step :owner_review,
                    role: "process_owner",
                    reason: "Validate the current-state representation before design work."

      step :finalize

      def finalize
        run.state[:finalize] = {
          current_state: run.state.fetch(:draft_current_state),
          review: run.approvals.last&.decision_payload
        }
      end
    end
  end
end
