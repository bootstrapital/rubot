# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class TopicVisibilityTrackingWorkflow < Rubot::Workflow
      tool_step :create_visibility_snapshot,
                tool: TopicBasedGeoExamples::TopicBasedGeo::CreateVisibilitySnapshotTool,
                input: ->(input, _state, _context) { { visibility_observations: input.fetch(:visibility_observations) } }

      agent_step :analyze_visibility,
                 agent: TopicBasedGeoExamples::TopicBasedGeo::VisibilityAnalysisAgent,
                 input: ->(_input, state, _context) { { visibility_snapshot: state.fetch(:create_visibility_snapshot) } }

      step :finalize
      output :finalize

      def finalize
        run.state[:finalize] = {
          snapshot: run.state.fetch(:create_visibility_snapshot),
          analysis: run.state.fetch(:analyze_visibility)
        }
      end
    end
  end
end
