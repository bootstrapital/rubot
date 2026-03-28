# frozen_string_literal: true

module ProcessOpsExamples
  module Sipoc
    class LoadProcessBriefTool < Rubot::Tool
      description "Load the initial process brief and normalize the scope."
      idempotent!

      input_schema do
        string :process_name
        array :stakeholders, of: :string
        array :artifacts, of: :string
        array :notes, of: :string
      end

      output_schema do
        string :process_name
        array :stakeholders, of: :string
        array :artifacts, of: :string
        array :notes, of: :string
      end

      def call(process_name:, stakeholders:, artifacts:, notes:)
        {
          process_name: process_name,
          stakeholders: stakeholders,
          artifacts: artifacts,
          notes: notes
        }
      end
    end
  end
end
