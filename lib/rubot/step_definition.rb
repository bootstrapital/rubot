# frozen_string_literal: true

module Rubot
  class StepDefinition
    attr_reader :kind, :name, :options, :block

    def initialize(kind:, name:, options: {}, block: nil)
      @kind = kind
      @name = name.to_sym
      @options = options
      @block = block
    end
  end
end
