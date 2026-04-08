# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class TopicMapStrategistAgent < Rubot::Agent
      instructions do
        "Turn product, market, and customer knowledge into a topic map for GEO content strategy."
      end

      input_schema do
        hash :program_brief
        hash :customer_evidence
        hash :market_landscape
      end

      output_schema do
        array :candidates, of: :hash
        array :coverage_gaps, of: :string
        array :recommended_clusters, of: :string
      end

      def perform(input:, run:, context:)
        brief = input.fetch(:program_brief)
        evidence = input.fetch(:customer_evidence)
        market = input.fetch(:market_landscape)

        candidates = []

        Array(evidence[:use_cases]).each do |use_case|
          candidates << { topic: "#{brief[:category]} for #{use_case}", type: "use_case" }
        end

        Array(evidence[:pain_points]).each do |pain|
          candidates << { topic: pain, type: "pain_point" }
        end

        Array(market[:comparison_angles]).each do |comparison|
          candidates << { topic: comparison, type: "competitor" }
        end

        {
          candidates: candidates,
          coverage_gaps: context.fetch(
            :coverage_gaps,
            ["case studies for high-friction migrations", "content for executive reporting scenarios"]
          ),
          recommended_clusters: ["use case pages", "competitor comparisons", "case studies"]
        }
      end
    end
  end
end
