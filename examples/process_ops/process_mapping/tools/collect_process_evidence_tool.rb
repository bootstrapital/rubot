# frozen_string_literal: true

module ProcessOpsExamples
  module ProcessMapping
    class CollectProcessEvidenceTool < Rubot::Tool
      description "Collect the main evidence needed to draft a current-state process map."
      idempotent!

      input_schema do
        string :process_name
        array :systems, of: :string
        array :actors, of: :string
        array :known_steps, of: :string
        array :known_exceptions, of: :string
      end

      output_schema do
        string :process_name
        array :systems, of: :string
        array :actors, of: :string
        array :known_steps, of: :string
        array :known_exceptions, of: :string
      end

      def call(process_name:, systems:, actors:, known_steps:, known_exceptions:)
        {
          process_name: process_name,
          systems: systems,
          actors: actors,
          known_steps: known_steps,
          known_exceptions: known_exceptions
        }
      end
    end
  end
end
