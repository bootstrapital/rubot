# frozen_string_literal: true

require_relative "tools/collect_process_evidence_tool"
require_relative "agents/draft_current_state_map_agent"
require_relative "workflow"

module ProcessOpsExamples
  module ProcessMapping
    class Operation < Rubot::Operation
      tool :collect_process_evidence, ProcessOpsExamples::ProcessMapping::CollectProcessEvidenceTool
      agent ProcessOpsExamples::ProcessMapping::DraftCurrentStateMapAgent
      workflow ProcessOpsExamples::ProcessMapping::Workflow
    end
  end
end
