# frozen_string_literal: true

module Rubot
  module Records
    class EventRecord < BaseRecord
      attributes :id, :run_record_id, :event_type, :step_name, :payload, :created_at
    end
  end
end
