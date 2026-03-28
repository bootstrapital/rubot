# frozen_string_literal: true

module ProcessOpsExamples
  module BottleneckAnalysis
    class Workflow < Rubot::Workflow
      tool_step :load_flow_metrics,
                tool: ProcessOpsExamples::BottleneckAnalysis::LoadFlowMetricsTool,
                input: lambda { |input, _state, _context|
                  {
                    process_name: input[:process_name],
                    stages: input[:stages],
                    observations: input[:observations]
                  }
                }

      agent_step :analyze_bottlenecks,
                 agent: ProcessOpsExamples::BottleneckAnalysis::AnalyzeBottlenecksAgent,
                 input: ->(_input, state, _context) { state.fetch(:load_flow_metrics) }

      approval_step :ops_review,
                    role: "ops_lead",
                    reason: "Validate bottlenecks and prioritize interventions."

      step :finalize

      def finalize
        run.state[:finalize] = {
          bottleneck_analysis: run.state.fetch(:analyze_bottlenecks),
          review: run.approvals.last&.decision_payload
        }
      end
    end
  end
end
