# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class LoadCustomerEvidenceTool < Rubot::Tool
      description "Normalize interview notes and customer-facing observations into reusable evidence."
      idempotent!

      input_schema do
        array :interview_notes, of: :string
        array :customer_pains, of: :string
        array :core_use_cases, of: :string
        array :differentiators, of: :string
      end

      output_schema do
        array :pain_points, of: :string
        array :use_cases, of: :string
        array :differentiators, of: :string
        array :proof_points, of: :string
      end

      def call(interview_notes:, customer_pains:, core_use_cases:, differentiators:)
        proof_points = interview_notes.map.with_index(1) do |note, index|
          "evidence_#{index}: #{note}"
        end

        {
          pain_points: customer_pains.uniq,
          use_cases: core_use_cases.uniq,
          differentiators: differentiators.uniq,
          proof_points: proof_points
        }
      end
    end
  end
end
