# frozen_string_literal: true

module Rubot
  class Event
    attr_reader :type, :step_name, :payload, :timestamp

    def initialize(type:, step_name: nil, payload: {}, timestamp: Rubot.configuration.time_source.call)
      @type = type
      @step_name = step_name
      @payload = payload
      @timestamp = timestamp
    end

    def to_h
      {
        type: type,
        step_name: step_name,
        payload: payload,
        timestamp: timestamp.iso8601
      }
    end

    def self.from_h(payload)
      new(
        type: payload[:type] || payload["type"],
        step_name: payload[:step_name] || payload["step_name"],
        payload: payload[:payload] || payload["payload"] || {},
        timestamp: parse_time(payload[:timestamp] || payload["timestamp"])
      )
    end

    def self.parse_time(value)
      case value
      when Time
        value
      when String
        Time.parse(value)
      else
        Rubot.configuration.time_source.call
      end
    end
  end
end
