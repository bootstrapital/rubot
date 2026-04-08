# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class CreateVisibilitySnapshotTool < Rubot::Tool
      description "Aggregate topic-level GEO visibility observations into a stable snapshot."
      idempotent!

      input_schema do
        array :visibility_observations, of: :hash
      end

      output_schema do
        integer :topic_count
        integer :visible_topics
        float :coverage_ratio
        array :topics, of: :hash
      end

      def call(visibility_observations:)
        topics = Array(visibility_observations).map { |observation| Rubot::HashUtils.symbolize(observation) }
        visible_topics = topics.count { |topic| topic[:cited] }
        topic_count = topics.length
        coverage_ratio = topic_count.zero? ? 0.0 : (visible_topics.to_f / topic_count).round(2)

        {
          topic_count: topic_count,
          visible_topics: visible_topics,
          coverage_ratio: coverage_ratio,
          topics: topics
        }
      end
    end
  end
end
