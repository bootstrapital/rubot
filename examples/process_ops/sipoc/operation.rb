# frozen_string_literal: true

require_relative "tools/load_process_brief_tool"
require_relative "agents/draft_sipoc_agent"
require_relative "workflow"

module ProcessOpsExamples
  module Sipoc
    class Operation < Rubot::Operation
      tool :load_process_brief, ProcessOpsExamples::Sipoc::LoadProcessBriefTool
      agent ProcessOpsExamples::Sipoc::DraftSipocAgent
      workflow ProcessOpsExamples::Sipoc::Workflow
    end
  end
end
