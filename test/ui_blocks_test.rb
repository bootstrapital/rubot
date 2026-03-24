# frozen_string_literal: true

require_relative "test_helper"
require_relative "../app/helpers/rubot/ui_helper"

class UiBlocksTest < Minitest::Test
  include Rubot::UiHelper

  def test_schema_field_helper_exposes_required_field_metadata
    schema = Rubot::Schema.build do
      string :ticket_id
      boolean :expedite, required: false
    end

    fields = rubot_schema_fields(schema)

    assert_equal [:ticket_id, :expedite], fields.map { |field| field[:name] }
    assert_equal true, fields.first[:required]
    assert_equal false, fields.last[:required]
  end

  def test_diff_rows_identify_added_removed_and_changed_values
    rows = rubot_diff_rows({ status: "open", old_value: "x" }, { status: "closed", new_value: "y" })

    assert_equal :removed, rows.find { |row| row[:key] == "old_value" }[:status]
    assert_equal :added, rows.find { |row| row[:key] == "new_value" }[:status]
    assert_equal :changed, rows.find { |row| row[:key] == "status" }[:status]
  end
end
