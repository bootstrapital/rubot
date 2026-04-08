# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class VisibilityAnalysisAgent < Rubot::Agent
      instructions do
        "Interpret topic-level visibility results and recommend next GEO actions."
      end

      input_schema do
        hash :visibility_snapshot
      end

      output_schema do
        array :wins, of: :string
        array :gaps, of: :string
        array :next_actions, of: :string
      end

      def perform(input:, run:, context:)
        snapshot = input.fetch(:visibility_snapshot)
        topics = snapshot.fetch(:topics)
        visible = topics.select { |topic| topic[:cited] }
        hidden = topics.reject { |topic| topic[:cited] }

        {
          wins: visible.map { |topic| "Visible in #{topic[:topic]}" },
          gaps: hidden.map { |topic| "Not yet visible in #{topic[:topic]}" },
          next_actions: context.fetch(
            :next_actions,
            [
              "Expand depth in the highest-value non-visible topics.",
              "Add case studies where recommendation confidence is weak."
            ]
          )
        }
      end
    end
  end
end
