# frozen_string_literal: true

require "active_support/core_ext/hash/keys"

module Rubot
  module HashUtils
    def self.symbolize(value)
      case value
      when Hash
        value.deep_symbolize_keys
      when Array
        value.map { |item| symbolize(item) }
      else
        value
      end
    end
  end
end
