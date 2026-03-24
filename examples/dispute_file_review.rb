# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "json"
require "tempfile"
require "rubot"

class DisputeFileReviewWorkflow < Rubot::Workflow
  tool_step :ingest_file,
            tool: Rubot::Tools::FileActions::IngestFile,
            input: ->(input, _state, _context) { { file_path: input[:file_path] } }

  tool_step :extract_fields,
            tool: Rubot::Tools::FileActions::ExtractFields,
            input: ->(_input, state, _context) { state.fetch(:ingest_file).slice(:content, :file_name) }

  tool_step :classify_document,
            tool: Rubot::Tools::FileActions::ClassifyDocument,
            input: ->(_input, state, _context) { state.fetch(:ingest_file).slice(:content, :file_name) }

  tool_step :generate_brief,
            tool: Rubot::Tools::FileActions::GenerateBrief,
            input: lambda { |_input, state, _context|
              state.fetch(:extract_fields).merge(
                state.fetch(:classify_document).slice(:category, :confidence)
              ).merge(file_name: state.fetch(:ingest_file)[:file_name])
            }

  approval_step :operator_review, role: "finance_ops", reason: "Operator review required before dispute response."

  step :finalize

  def finalize
    run.state[:finalize] = {
      brief: run.state.fetch(:generate_brief),
      approved_by: run.approvals.last&.decision_payload&.dig(:approved_by)
    }
  end
end

sample = Tempfile.new(["dispute_review", ".txt"])
sample.write(<<~TEXT)
  Dispute ID: DSP-2049
  Customer: Ada Lovelace
  Amount: $142.55
  Transaction Date: 2026-03-01
  This chargeback packet disputes a duplicate transaction.
TEXT
sample.flush

run = Rubot.run(DisputeFileReviewWorkflow, input: { file_path: sample.path })
puts JSON.pretty_generate(run.to_h)

if run.waiting_for_approval?
  run.approve!(approved_by: "ops@example.com", note: "Route to dispute response queue")
  Rubot::Executor.new.resume(DisputeFileReviewWorkflow, run)
  puts JSON.pretty_generate(run.to_h)
end

sample.close!
