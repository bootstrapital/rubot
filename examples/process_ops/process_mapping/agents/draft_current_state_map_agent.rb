# frozen_string_literal: true

module ProcessOpsExamples
  module ProcessMapping
    class DraftCurrentStateMapAgent < Rubot::Agent
      instructions do
        "Draft a current-state process map with handoffs, approvals, and exception paths."
      end

      input_schema do
        string :process_name
        array :systems, of: :string
        array :actors, of: :string
        array :known_steps, of: :string
        array :known_exceptions, of: :string
      end

      output_schema do
        array :stages, of: :hash
        array :handoffs, of: :string
        array :approval_points, of: :string
        array :exception_paths, of: :string
        array :follow_up_questions, of: :string
      end

      def perform(input:, run:, context:)
        stages =
          input[:known_steps].map.with_index(1) do |step_name, index|
            {
              order: index,
              name: step_name,
              actor: input[:actors][[index - 1, input[:actors].length - 1].min],
              system: input[:systems][[index - 1, input[:systems].length - 1].min]
            }
          end

        {
          stages: stages,
          handoffs: context.fetch(:handoffs, default_handoffs(stages)),
          approval_points: context.fetch(
            :approval_points,
            ["Manager review before final resolution", "Policy review for non-standard cases"]
          ),
          exception_paths: context.fetch(:exception_paths, input[:known_exceptions]),
          follow_up_questions: context.fetch(
            :follow_up_questions,
            ["What triggers rework?", "Where do operators leave the main system to finish the job?"]
          )
        }
      end

      private

      def default_handoffs(stages)
        stages.each_cons(2).map do |left, right|
          "#{left[:actor]} hands work from #{left[:name]} to #{right[:actor]} for #{right[:name]}"
        end
      end
    end
  end
end
