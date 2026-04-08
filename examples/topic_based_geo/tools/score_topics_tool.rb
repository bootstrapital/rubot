# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class ScoreTopicsTool < Rubot::Tool
      description "Score topics by commercial fit, specificity, and evidence coverage."
      idempotent!

      input_schema do
        array :topics, of: :hash
        array :proof_points, of: :string
      end

      output_schema do
        array :topics, of: :hash
      end

      def call(topics:, proof_points:)
        scored_topics =
          topics.map do |topic|
            normalized = Rubot::HashUtils.symbolize(topic)
            score = 0.45
            score += 0.2 if normalized[:type] == "competitor"
            score += 0.15 if normalized[:type] == "use_case"
            score += 0.1 if normalized[:type] == "pain_point"
            score += 0.1 if proof_points.any?

            normalized.merge(priority_score: score.round(2))
          end

        { topics: scored_topics.sort_by { |topic| -topic.fetch(:priority_score) } }
      end
    end
  end
end
