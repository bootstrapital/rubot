# frozen_string_literal: true

module ProcessOpsExamples
  module Sipoc
    class DraftSipocAgent < Rubot::Agent
      instructions do
        "Draft a SIPOC view of the process from the provided brief."
      end

      input_schema do
        string :process_name
        array :stakeholders, of: :string
        array :artifacts, of: :string
        array :notes, of: :string
      end

      output_schema do
        array :suppliers, of: :string
        array :inputs, of: :string
        array :high_level_process, of: :string
        array :outputs, of: :string
        array :customers, of: :string
        array :open_questions, of: :string
      end

      def perform(input:, run:, context:)
        stakeholders = input[:stakeholders]
        artifacts = input[:artifacts]

        {
          suppliers: context.fetch(:suppliers, stakeholders.first(3)),
          inputs: context.fetch(:inputs, artifacts.first(3) + ["operator judgment"]),
          high_level_process: context.fetch(:high_level_process, default_process_steps(input[:process_name])),
          outputs: context.fetch(:outputs, ["completed #{input[:process_name].downcase}", "decision summary"]),
          customers: context.fetch(:customers, stakeholders.last(2)),
          open_questions: context.fetch(:open_questions, default_open_questions(input[:notes]))
        }
      end

      private

      def default_process_steps(process_name)
        [
          "Receive #{process_name} intake",
          "Review completeness and clarify missing context",
          "Perform the core #{process_name.downcase} work",
          "Review or approve the outcome"
        ]
      end

      def default_open_questions(notes)
        matches = notes.grep(/unclear|unknown|missing/i)
        matches.empty? ? ["Which exceptions deserve separate handling?"] : matches
      end
    end
  end
end
