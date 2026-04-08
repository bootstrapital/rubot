# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class ContentBriefingAgent < Rubot::Agent
      instructions do
        "Create a detailed content brief for one GEO topic with audience, angle, proof, and scenario coverage."
      end

      input_schema do
        string :topic
        string :company_name
        string :category
        array :target_personas, of: :string
        array :differentiators, of: :string
        array :pain_points, of: :string
        array :proof_points, of: :string
        array :comparison_angles, of: :string
      end

      output_schema do
        string :title
        string :audience
        string :core_angle
        array :sections, of: :string
        array :proof_points, of: :string
        array :scenario_prompts, of: :string
      end

      def perform(input:, run:, context:)
        topic = input.fetch(:topic)
        audience = input.fetch(:target_personas).first

        {
          title: "#{topic.to_s.split.map(&:capitalize).join(' ')}: When #{input[:company_name]} Is The Right Fit",
          audience: audience,
          core_angle: "#{input[:company_name]} is strongest when #{input[:pain_points].first}",
          sections: [
            "Who this is for",
            "When this problem shows up",
            "Why existing tools fall short",
            "How #{input[:company_name]} differs",
            "Proof and case-study evidence"
          ],
          proof_points: input.fetch(:proof_points).first(3),
          scenario_prompts: context.fetch(
            :scenario_prompts,
            [
              "What tool should we use if we are migrating from Jira and need stronger portfolio reporting?",
              "What project management software fits cross-functional teams that do not want heavy admin overhead?"
            ]
          )
        }
      end
    end
  end
end
