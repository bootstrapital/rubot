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

    def condition_met?(workflow)
      if options[:if]
        evaluate_condition(workflow, options[:if])
      elsif options[:unless]
        !evaluate_condition(workflow, options[:unless])
      else
        true
      end
    end

    private

    def evaluate_condition(workflow, condition)
      case condition
      when Symbol
        workflow.public_send(condition)
      when Proc
        workflow.instance_exec(workflow.run.input, workflow.run.state, workflow.run.context, &condition)
      else
        condition
      end
    end
  end
end
