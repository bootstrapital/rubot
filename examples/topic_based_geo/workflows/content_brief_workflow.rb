# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class ContentBriefWorkflow < Rubot::Workflow
      tool_step :load_program_brief,
                tool: TopicBasedGeoExamples::TopicBasedGeo::LoadGeoProgramBriefTool,
                input: lambda { |input, _state, _context|
                  input.slice(
                    :company_name,
                    :category,
                    :product_summary,
                    :target_personas,
                    :core_use_cases,
                    :differentiators,
                    :competitors,
                    :customer_pains
                  )
                }

      tool_step :load_customer_evidence,
                tool: TopicBasedGeoExamples::TopicBasedGeo::LoadCustomerEvidenceTool,
                input: lambda { |input, state, _context|
                  {
                    interview_notes: input[:interview_notes],
                    customer_pains: state.fetch(:load_program_brief).fetch(:customer_pains),
                    core_use_cases: state.fetch(:load_program_brief).fetch(:core_use_cases),
                    differentiators: state.fetch(:load_program_brief).fetch(:differentiators)
                  }
                }

      tool_step :load_market_landscape,
                tool: TopicBasedGeoExamples::TopicBasedGeo::LoadMarketLandscapeTool,
                input: lambda { |_input, state, _context|
                  brief = state.fetch(:load_program_brief)
                  {
                    category: brief.fetch(:category),
                    competitors: brief.fetch(:competitors),
                    target_personas: brief.fetch(:target_personas)
                  }
                }

      agent_step :build_brief,
                 agent: TopicBasedGeoExamples::TopicBasedGeo::ContentBriefingAgent,
                 input: lambda { |input, state, _context|
                   brief = state.fetch(:load_program_brief)
                   evidence = state.fetch(:load_customer_evidence)
                   market = state.fetch(:load_market_landscape)

                   {
                     topic: input.fetch(:topic),
                     company_name: brief.fetch(:company_name),
                     category: brief.fetch(:category),
                     target_personas: brief.fetch(:target_personas),
                     differentiators: evidence.fetch(:differentiators),
                     pain_points: evidence.fetch(:pain_points),
                     proof_points: evidence.fetch(:proof_points),
                     comparison_angles: market.fetch(:comparison_angles)
                   }
                 }

      approval_step :editorial_review,
                    role: "editor",
                    reason: "Approve the brief before drafting begins."

      step :finalize
      output :finalize

      def finalize
        run.state[:finalize] = {
          brief: run.state.fetch(:build_brief),
          review: run.approvals.last&.decision_payload
        }
      end
    end
  end
end
