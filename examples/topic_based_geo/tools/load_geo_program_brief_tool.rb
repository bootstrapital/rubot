# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class LoadGeoProgramBriefTool < Rubot::Tool
      description "Load the canonical GEO strategy brief for the selected company."
      idempotent!

      input_schema do
        string :company_name
        string :category
        string :product_summary
        array :target_personas, of: :string
        array :core_use_cases, of: :string
        array :differentiators, of: :string
        array :competitors, of: :string
        array :customer_pains, of: :string
      end

      output_schema do
        string :company_name
        string :category
        string :product_summary
        array :target_personas, of: :string
        array :core_use_cases, of: :string
        array :differentiators, of: :string
        array :competitors, of: :string
        array :customer_pains, of: :string
      end

      def call(company_name:, category:, product_summary:, target_personas:, core_use_cases:, differentiators:, competitors:, customer_pains:)
        {
          company_name: company_name,
          category: category,
          product_summary: product_summary,
          target_personas: target_personas,
          core_use_cases: core_use_cases,
          differentiators: differentiators,
          competitors: competitors,
          customer_pains: customer_pains
        }
      end
    end
  end
end
