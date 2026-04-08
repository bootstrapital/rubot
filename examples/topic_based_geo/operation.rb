# frozen_string_literal: true

require_relative "tools/load_geo_program_brief_tool"
require_relative "tools/load_customer_evidence_tool"
require_relative "tools/load_market_landscape_tool"
require_relative "tools/normalize_topic_candidates_tool"
require_relative "tools/score_topics_tool"
require_relative "tools/build_source_packet_tool"
require_relative "tools/create_visibility_snapshot_tool"

require_relative "agents/topic_map_strategist_agent"
require_relative "agents/content_briefing_agent"
require_relative "agents/long_form_drafting_agent"
require_relative "agents/visibility_analysis_agent"

require_relative "workflows/topic_map_discovery_workflow"
require_relative "workflows/content_brief_workflow"
require_relative "workflows/content_draft_workflow"
require_relative "workflows/topic_visibility_tracking_workflow"

module TopicBasedGeoExamples
  module TopicBasedGeo
    class Operation < Rubot::Operation
      tool :load_geo_program_brief, TopicBasedGeoExamples::TopicBasedGeo::LoadGeoProgramBriefTool
      tool :load_customer_evidence, TopicBasedGeoExamples::TopicBasedGeo::LoadCustomerEvidenceTool
      tool :load_market_landscape, TopicBasedGeoExamples::TopicBasedGeo::LoadMarketLandscapeTool
      tool :normalize_topic_candidates, TopicBasedGeoExamples::TopicBasedGeo::NormalizeTopicCandidatesTool
      tool :score_topics, TopicBasedGeoExamples::TopicBasedGeo::ScoreTopicsTool
      tool :build_source_packet, TopicBasedGeoExamples::TopicBasedGeo::BuildSourcePacketTool
      tool :create_visibility_snapshot, TopicBasedGeoExamples::TopicBasedGeo::CreateVisibilitySnapshotTool

      agent :topic_map_strategist, TopicBasedGeoExamples::TopicBasedGeo::TopicMapStrategistAgent
      agent :content_briefing, TopicBasedGeoExamples::TopicBasedGeo::ContentBriefingAgent
      agent :long_form_drafting, TopicBasedGeoExamples::TopicBasedGeo::LongFormDraftingAgent
      agent :visibility_analysis, TopicBasedGeoExamples::TopicBasedGeo::VisibilityAnalysisAgent

      workflow :topic_map_discovery, TopicBasedGeoExamples::TopicBasedGeo::TopicMapDiscoveryWorkflow, default: true
      workflow :content_brief, TopicBasedGeoExamples::TopicBasedGeo::ContentBriefWorkflow
      workflow :content_draft, TopicBasedGeoExamples::TopicBasedGeo::ContentDraftWorkflow
      workflow :topic_visibility_tracking, TopicBasedGeoExamples::TopicBasedGeo::TopicVisibilityTrackingWorkflow

      trigger :manual

      entrypoint :build_strategy, workflow: :topic_map_discovery
      entrypoint :brief_topic, workflow: :content_brief
      entrypoint :draft_topic, workflow: :content_draft
      entrypoint :track_visibility, workflow: :topic_visibility_tracking
    end
  end
end
