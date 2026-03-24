# frozen_string_literal: true

require_relative "test_helper"
require "tempfile"

class FileActionsWorkflow < Rubot::Workflow
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
end

class FileActionsToolPackTest < Minitest::Test
  def setup
    @sample = Tempfile.new(["chargeback", ".txt"])
    @sample.write(<<~TEXT)
      Dispute ID: DSP-2049
      Invoice: INV-100
      Customer: Ada Lovelace
      Amount: $142.55
      Transaction Date: 2026-03-01
      The customer opened a chargeback on this purchase.
    TEXT
    @sample.flush
  end

  def teardown
    @sample.close!
  end

  def test_ingest_file_reads_content
    result = Rubot::Tools::FileActions::IngestFile.call(file_path: @sample.path)

    assert_equal File.basename(@sample.path), result[:file_name]
    assert_includes result[:content], "Dispute ID"
    assert_operator result[:line_count], :>, 1
  end

  def test_extract_fields_and_classification_are_typed
    ingest = Rubot::Tools::FileActions::IngestFile.call(file_path: @sample.path)
    fields = Rubot::Tools::FileActions::ExtractFields.call(content: ingest[:content], file_name: ingest[:file_name])
    classification = Rubot::Tools::FileActions::ClassifyDocument.call(content: ingest[:content], file_name: ingest[:file_name])

    assert_equal "DSP-2049", fields[:dispute_id]
    assert_equal "INV-100", fields[:invoice_id]
    assert_equal "Ada Lovelace", fields[:customer_name]
    assert_equal 142.55, fields[:amount]
    assert_equal "dispute", classification[:category]
    assert_operator classification[:confidence], :>, 0.8
  end

  def test_workflow_generates_operator_brief
    run = Rubot.run(FileActionsWorkflow, input: { file_path: @sample.path })

    assert_equal :completed, run.status
    assert_equal "dispute", run.state[:classify_document][:category]
    assert_equal "prepare_dispute_response", run.output[:generate_brief][:recommended_action]
    assert_includes run.output[:generate_brief][:headline], "Dispute review"
  end
end
