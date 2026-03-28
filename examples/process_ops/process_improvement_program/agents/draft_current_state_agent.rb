# frozen_string_literal: true

module ProcessOpsExamples
  module ProcessImprovementProgram
    class DraftCurrentStateAgent < Rubot::Agent
      instructions do
        "Draft a current-state summary with stages, handoffs, and operational pain points."
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
        array :stages, of: :hash
        array :handoffs, of: :string
        array :pain_themes, of: :string
        array :questions, of: :string
      end

      def perform(input:, run:, context:)
        stages =
          input[:known_steps].map.with_index(1) do |step_name, index|
            {
              order: index,
              name: step_name,
              actor: input[:stakeholders][[index - 1, input[:stakeholders].length - 1].min],
              system: input[:systems][[index - 1, input[:systems].length - 1].min]
            }
          end

        {
          stages: stages,
          handoffs: stages.each_cons(2).map do |left, right|
            "#{left[:actor]} hands off from #{left[:name]} to #{right[:actor]} for #{right[:name]}"
          end,
          pain_themes: input[:pain_points],
          questions: context.fetch(
            :current_state_questions,
            ["Which exceptions fall outside the happy path?", "Where does work leave the main system?"]
          )
        }
      end
    end
  end
end
