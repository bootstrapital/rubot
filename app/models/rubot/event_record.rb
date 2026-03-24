# frozen_string_literal: true

module Rubot
  class EventRecord < ApplicationRecord
    self.table_name = "rubot_event_records"

    belongs_to :run_record, class_name: "Rubot::RunRecord", inverse_of: :event_records
  end
end
