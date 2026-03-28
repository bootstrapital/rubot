# frozen_string_literal: true

module ResumeScreener
  class Operation < Rubot::Operation
    JOB_DESCRIPTIONS = {
      "rails_support_engineer" => {
        title: "Rails Support Engineer",
        team: "Support Engineering",
        location: "Remote, US",
        summary: "Own technical escalations, debug Rails production issues, and collaborate directly with customers.",
        must_haves: [
          "Ruby on Rails",
          "SQL",
          "customer communication",
          "debugging"
        ],
        preferred: [
          "background jobs",
          "incident response",
          "API integrations"
        ]
      },
      "ai_ops_analyst" => {
        title: "AI Operations Analyst",
        team: "Operations",
        location: "Hybrid, Detroit",
        summary: "Review AI-assisted workflows, spot operational risk, and partner with engineering on tooling improvements.",
        must_haves: [
          "workflow operations",
          "written communication",
          "data analysis",
          "stakeholder management"
        ],
        preferred: [
          "prompt design",
          "quality assurance",
          "Ruby or Python"
        ]
      }
    }.freeze

    def self.job_options
      JOB_DESCRIPTIONS.map do |id, details|
        ["#{details[:title]} (#{details[:team]})", id]
      end
    end

    def self.job_description(job_id)
      JOB_DESCRIPTIONS.fetch(job_id.to_s)
    end

    tool :load_job_description, ResumeScreener::LoadJobDescriptionTool
    tool :prepare_resume, ResumeScreener::PrepareResumeTool
    agent ResumeScreener::ScreeningAgent
    workflow :screening, ResumeScreener::Workflow, default: true
    entrypoint :screen_resume, workflow: :screening
  end
end
