# frozen_string_literal: true

module ProcessOpsExamples
  module BottleneckAnalysis
    class LoadFlowMetricsTool < Rubot::Tool
      description "Load the metrics and observations needed for bottleneck analysis."
      idempotent!

      input_schema do
        string :process_name
        array :stages, of: :hash
        array :observations, of: :string
      end

      output_schema do
        string :process_name
        array :stages, of: :hash
        array :observations, of: :string
      end

      def call(process_name:, stages:, observations:)
        {
          process_name: process_name,
          stages: stages,
          observations: observations
        }
      end
    end
  end
end
