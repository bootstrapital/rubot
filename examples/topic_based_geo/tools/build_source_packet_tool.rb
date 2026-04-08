# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class BuildSourcePacketTool < Rubot::Tool
      description "Assemble the factual source packet used for briefing and drafting."
      idempotent!

      input_schema do
        hash :brief
        hash :customer_evidence
        hash :market_landscape
      end

      output_schema do
        hash :brief
        hash :customer_evidence
        hash :market_landscape
        array :required_sections, of: :string
      end

      def call(brief:, customer_evidence:, market_landscape:)
        {
          brief: brief,
          customer_evidence: customer_evidence,
          market_landscape: market_landscape,
          required_sections: [
            "who this is for",
            "specific scenarios",
            "pain points and outcomes",
            "comparison angles",
            "proof points"
          ]
        }
      end
    end
  end
end
