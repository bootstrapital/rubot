# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class NormalizeTopicCandidatesTool < Rubot::Tool
      description "Dedupe and normalize topic candidates into a stable topic-map shape."
      idempotent!

      input_schema do
        array :candidates, of: :hash
      end

      output_schema do
        array :topics, of: :hash
      end

      def call(candidates:)
        topics =
          Array(candidates).each_with_object({}) do |candidate, memo|
            normalized = Rubot::HashUtils.symbolize(candidate)
            key = normalized.fetch(:topic).downcase.strip
            memo[key] ||= normalized.merge(topic: key)
          end

        { topics: topics.values.sort_by { |topic| topic.fetch(:topic) } }
      end
    end
  end
end
