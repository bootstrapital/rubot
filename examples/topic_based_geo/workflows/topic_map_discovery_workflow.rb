# frozen_string_literal: true

module TopicBasedGeoExamples
  module TopicBasedGeo
    class TopicMapDiscoveryWorkflow < Rubot::Workflow
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

      agent_step :draft_topic_candidates,
                 agent: TopicBasedGeoExamples::TopicBasedGeo::TopicMapStrategistAgent,
                 input: lambda { |_input, state, _context|
                   {
                     program_brief: state.fetch(:load_program_brief),
                     customer_evidence: state.fetch(:load_customer_evidence),
                     market_landscape: state.fetch(:load_market_landscape)
                   }
                 }

      tool_step :normalize_topic_candidates,
                tool: TopicBasedGeoExamples::TopicBasedGeo::NormalizeTopicCandidatesTool,
                input: ->(_input, state, _context) { { candidates: state.fetch(:draft_topic_candidates).fetch(:candidates) } }

      tool_step :score_topics,
                tool: TopicBasedGeoExamples::TopicBasedGeo::ScoreTopicsTool,
                input: lambda { |_input, state, _context|
                  {
                    topics: state.fetch(:normalize_topic_candidates).fetch(:topics),
                    proof_points: state.fetch(:load_customer_evidence).fetch(:proof_points)
                  }
                }

      approval_step :strategy_review,
                    role: "content_strategist",
                    reason: "Review the proposed topic map before it becomes the operating backlog."

      step :finalize
      output :finalize

      def finalize
        run.state[:finalize] = {
          topic_map: run.state.fetch(:score_topics).fetch(:topics),
          coverage_gaps: run.state.fetch(:draft_topic_candidates).fetch(:coverage_gaps),
          recommended_clusters: run.state.fetch(:draft_topic_candidates).fetch(:recommended_clusters),
          review: run.approvals.last&.decision_payload
        }
      end
    end
  end
end
