# frozen_string_literal: true

module ProcessOpsExamples
  module ProcessImprovementProgram
    class LoadProgramBriefTool < Rubot::Tool
      description "Load the shared process improvement brief for the selected workflow path."
      idempotent!

      input_schema do
        string :process_name
        array :stakeholders, of: :string
        array :systems, of: :string
        array :known_steps, of: :string
        array :pain_points, of: :string
        array :constraints, of: :string
      end

      output_schema do
        string :process_name
        array :stakeholders, of: :string
        array :systems, of: :string
        array :known_steps, of: :string
        array :pain_points, of: :string
        array :constraints, of: :string
      end

      def call(process_name:, stakeholders:, systems:, known_steps:, pain_points:, constraints:)
        {
          process_name: process_name,
          stakeholders: stakeholders,
          systems: systems,
          known_steps: known_steps,
          pain_points: pain_points,
          constraints: constraints
        }
      end
    end
  end
end
