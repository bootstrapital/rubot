# frozen_string_literal: true

module ProcessOpsExamples
  module ProcessImprovementProgram
    class FutureStateWorkflow < Rubot::Workflow
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

      agent_step :design_future_state,
                 agent: ProcessOpsExamples::ProcessImprovementProgram::DesignFutureStateAgent,
                 input: ->(_input, state, _context) { state.fetch(:load_program_brief) }

      approval_step :sponsor_review,
                    role: "program_sponsor",
                    reason: "Review the proposed future-state design before implementation."

      step :finalize

      def finalize
        run.state[:finalize] = {
          future_state: run.state.fetch(:design_future_state),
          review: run.approvals.last&.decision_payload
        }
      end
    end
  end
end
