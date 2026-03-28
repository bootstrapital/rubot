# frozen_string_literal: true

module ProcessOpsExamples
  module BottleneckAnalysis
    class AnalyzeBottlenecksAgent < Rubot::Agent
      instructions do
        "Identify likely bottlenecks, queues, and rework loops in the process."
      end

      input_schema do
        string :process_name
        array :stages, of: :hash
        array :observations, of: :string
      end

      output_schema do
        array :bottlenecks, of: :hash
        array :systemic_causes, of: :string
        array :recommended_interventions, of: :string
      end

      def perform(input:, run:, context:)
        ranked_stages = input[:stages].sort_by { |stage| -(stage[:wait_hours].to_i + stage[:rework_count].to_i * 4) }

        {
          bottlenecks: ranked_stages.first(2).map do |stage|
            {
              stage: stage[:name],
              owner: stage[:owner],
              wait_hours: stage[:wait_hours],
              rework_count: stage[:rework_count],
              reason: "High wait time and repeated rework"
            }
          end,
          systemic_causes: context.fetch(
            :systemic_causes,
            [
              "Approvals happen late and without enough context",
              "Operators switch systems to gather the evidence needed for review"
            ]
          ),
          recommended_interventions: context.fetch(
            :recommended_interventions,
            [
              "Move evidence gathering earlier in the workflow",
              "Create a standard review brief before approval",
              "Define a separate path for non-standard exceptions"
            ]
          )
        }
      end
    end
  end
end
