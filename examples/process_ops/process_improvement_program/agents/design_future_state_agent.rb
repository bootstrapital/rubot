# frozen_string_literal: true

module ProcessOpsExamples
  module ProcessImprovementProgram
    class DesignFutureStateAgent < Rubot::Agent
      instructions do
        "Design a future-state workflow that addresses the pain points while respecting stated constraints."
      end

      input_schema do
        string :process_name
        array :stakeholders, of: :string
        array :systems, of: :string
        array :known_steps, of: :string
        array :pain_points, of: :string
        array :constraints, of: :string
      end

      output_schema do
        array :proposed_stages, of: :hash
        array :design_principles, of: :string
        array :expected_improvements, of: :string
        array :open_risks, of: :string
      end

      def perform(input:, run:, context:)
        proposed_stages = [
          { order: 1, name: "Standardize intake and required context", owner: input[:stakeholders].first },
          { order: 2, name: "Route normal cases automatically", owner: input[:stakeholders][1] || input[:stakeholders].first },
          { order: 3, name: "Send exception cases to guided review", owner: input[:stakeholders][2] || input[:stakeholders].last },
          { order: 4, name: "Capture decision and write back to systems", owner: input[:stakeholders].last }
        ]

        {
          proposed_stages: context.fetch(:proposed_stages, proposed_stages),
          design_principles: context.fetch(
            :design_principles,
            [
              "Gather context once near the start of the workflow",
              "Separate happy path handling from exception handling",
              "Keep final business decisions behind explicit review when risk is non-trivial"
            ]
          ),
          expected_improvements: context.fetch(
            :expected_improvements,
            [
              "Less back-and-forth during review",
              "Shorter wait time for standard cases",
              "Clearer visibility into where work is blocked"
            ]
          ),
          open_risks: context.fetch(
            :open_risks,
            input[:constraints].map { |constraint| "Design must respect constraint: #{constraint}" }
          )
        }
      end
    end
  end
end
