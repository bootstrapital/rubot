# frozen_string_literal: true

require_relative "tools/load_program_brief_tool"
require_relative "agents/draft_current_state_agent"
require_relative "agents/design_future_state_agent"
require_relative "workflows/current_state_workflow"
require_relative "workflows/future_state_workflow"

module ProcessOpsExamples
  module ProcessImprovementProgram
    class Operation < Rubot::Operation
      tool :load_program_brief, ProcessOpsExamples::ProcessImprovementProgram::LoadProgramBriefTool
      agent :draft_current_state, ProcessOpsExamples::ProcessImprovementProgram::DraftCurrentStateAgent
      agent :design_future_state, ProcessOpsExamples::ProcessImprovementProgram::DesignFutureStateAgent
      workflow :current_state, ProcessOpsExamples::ProcessImprovementProgram::CurrentStateWorkflow, default: true
      workflow :future_state, ProcessOpsExamples::ProcessImprovementProgram::FutureStateWorkflow

      trigger :manual
      trigger :future_state_design,
              workflow: :future_state,
              context: ->(_payload, _subject, context) { context.merge(program_mode: "future_state_design") }
    end
  end
end
