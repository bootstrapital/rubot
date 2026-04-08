# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class LoadMarketLandscapeTool < Rubot::Tool
      description "Package category and competitor context for GEO strategy work."
      idempotent!

      input_schema do
        string :category
        array :competitors, of: :string
        array :target_personas, of: :string
      end

      output_schema do
        string :category
        array :competitors, of: :string
        array :comparison_angles, of: :string
        array :persona_angles, of: :string
      end

      def call(category:, competitors:, target_personas:)
        {
          category: category,
          competitors: competitors,
          comparison_angles: competitors.map { |competitor| "#{competitor} alternatives" },
          persona_angles: target_personas.map { |persona| "#{category} for #{persona}" }
        }
      end
    end
  end
end
