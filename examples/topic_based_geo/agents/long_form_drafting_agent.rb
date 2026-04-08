# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class LongFormDraftingAgent < Rubot::Agent
      instructions do
        "Draft a content asset at the depth of a strong sales conversation, not an introductory SEO article."
      end

      input_schema do
        hash :brief
        hash :source_packet
      end

      output_schema do
        string :headline
        array :sections, of: :hash
        array :editor_notes, of: :string
      end

      def perform(input:, run:, context:)
        brief = input.fetch(:brief)

        sections = brief.fetch(:sections).map do |section|
          {
            heading: section,
            summary: "Draft section for #{section.downcase} grounded in the brief and source packet."
          }
        end

        {
          headline: brief.fetch(:title),
          sections: sections,
          editor_notes: context.fetch(
            :editor_notes,
            [
              "Add screenshots or concrete product examples.",
              "Strengthen proof where claims rely on internal positioning."
            ]
          )
        }
      end
    end
  end
end
