# frozen_string_literal: true

require_relative "tools/load_flow_metrics_tool"
require_relative "agents/analyze_bottlenecks_agent"
require_relative "workflow"

module ProcessOpsExamples
  module BottleneckAnalysis
    class Operation < Rubot::Operation
      tool :load_flow_metrics, ProcessOpsExamples::BottleneckAnalysis::LoadFlowMetricsTool
      agent ProcessOpsExamples::BottleneckAnalysis::AnalyzeBottlenecksAgent
      workflow ProcessOpsExamples::BottleneckAnalysis::Workflow
    end
  end
end
