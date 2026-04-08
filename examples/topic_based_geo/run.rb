# frozen_string_literal: true

require_relative "../../lib/rubot"
require_relative "operation"

Rubot.configure do |config|
  config.store = Rubot::Stores::MemoryStore.new
end

payload = {
  company_name: "AcmePM",
  category: "project management software",
  product_summary: "Project management software for mid-market and enterprise teams migrating off Jira.",
  target_personas: ["operations leader", "platform lead", "PMO director"],
  core_use_cases: [
    "migrating from Jira",
    "cross-functional portfolio visibility",
    "enterprise governance without admin sprawl"
  ],
  differentiators: [
    "faster onboarding than Jira",
    "stronger executive reporting",
    "workflow customization without heavy admin overhead"
  ],
  competitors: ["Jira", "Asana", "Monday.com"],
  customer_pains: [
    "Jira is too complex for non-technical teams",
    "leadership cannot see portfolio health clearly",
    "teams want process flexibility without hiring admins"
  ],
  interview_notes: [
    "Sales hears Jira migration requests weekly.",
    "Buyers ask about rollout speed and cross-functional adoption.",
    "Prospects care about portfolio visibility more than task tracking."
  ],
  visibility_observations: [
    { topic: "jira alternatives for operations teams", cited: true, score: 0.72 },
    { topic: "enterprise project management software", cited: false, score: 0.31 }
  ]
}

run = TopicBasedGeoExamples::TopicBasedGeo::Operation.launch_build_strategy(payload: payload)

puts "Run status: #{run.status}"
puts "Output:"
pp run.output
