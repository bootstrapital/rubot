# frozen_string_literal: true

module Rubot
  class Run
    STATUSES = %i[queued running waiting_for_approval completed failed canceled].freeze

    attr_accessor :current_step, :output, :error, :state
    attr_reader :id, :name, :kind, :status, :subject, :input, :context, :events, :approvals, :started_at, :completed_at, :tool_calls

    def initialize(name:, kind:, input:, subject: nil, context: {}, id: nil, status: :queued, state: {}, output: nil, error: nil, current_step: nil, started_at: nil, completed_at: nil, events: [], approvals: [], tool_calls: [], persist: true)
      @id = id || Rubot.configuration.id_generator.call
      @name = name
      @kind = kind
      @input = input
      @subject = subject
      @context = context
      @state = state
      @events = events
      @approvals = approvals
      @tool_calls = tool_calls
      @status = status.to_sym
      @output = output
      @error = error
      @current_step = current_step
      @started_at = started_at
      @completed_at = completed_at
      persist! if persist
    end

    def queued?
      status == :queued
    end

    def running?
      status == :running
    end

    def waiting_for_approval?
      status == :waiting_for_approval
    end

    def completed?
      status == :completed
    end

    def failed?
      status == :failed
    end

    def start!
      @status = :running
      @started_at ||= Rubot.configuration.time_source.call
      persist!
    end

    def wait_for_approval!
      @status = :waiting_for_approval
      persist!
    end

    def complete!(output = nil)
      @output = output
      @status = :completed
      @completed_at = Rubot.configuration.time_source.call
      persist!
    end

    def fail!(error)
      @error = error
      @status = :failed
      @completed_at = Rubot.configuration.time_source.call
      persist!
    end

    def add_event(event)
      events << event
      Rubot.configuration.event_subscriber&.call(self, event)
      persist!
      event
    end

    def add_approval(approval)
      approvals << approval
      persist!
      approval
    end

    def add_tool_call(tool_call)
      tool_calls << tool_call
      persist!
      tool_call
    end

    def pending_approval
      approvals.reverse.find(&:pending?)
    end

    def approve!(payload = {})
      approval = pending_approval
      raise ApprovalRequired, "No pending approval exists for this run" unless approval

      approval.approve!(payload)
      @status = :running
      persist!
      approval
    end

    def reject!(payload = {})
      approval = pending_approval
      raise ApprovalRequired, "No pending approval exists for this run" unless approval

      approval.reject!(payload)
      fail!(payload.merge(type: "rejected"))
      approval
    end

    def request_changes!(payload = {})
      approval = pending_approval
      raise ApprovalRequired, "No pending approval exists for this run" unless approval

      approval.request_changes!(payload)
      fail!(payload.merge(type: "changes_requested"))
      approval
    end

    def check_approval_slas!(time: Rubot.configuration.time_source.call)
      approvals.each do |approval|
        next unless approval.pending?

        if approval.overdue?(time)
          add_event(Event.new(type: "approval.overdue", step_name: approval.step_name, payload: approval.to_h))
        end

        next unless approval.expired?(time)

        approval.expire!
        fail!(type: "approval_expired", step_name: approval.step_name, expired_at: time.iso8601)
        add_event(Event.new(type: "approval.expired", step_name: approval.step_name, payload: approval.to_h))
      end

      self
    end

    def persist!
      Rubot.store.save_run(self)
      Rubot::LiveUpdates.broadcast_run(self)
      self
    end

    def self.restore(**attrs)
      new(**attrs, persist: false)
    end

    def to_h
      {
        id: id,
        name: name,
        kind: kind,
        status: status,
        current_step: current_step,
        input: input,
        state: state,
        output: output,
        error: error,
        subject: subject,
        context: context,
        approvals: approvals.map(&:to_h),
        events: events.map(&:to_h),
        tool_calls: tool_calls,
        started_at: started_at&.iso8601,
        completed_at: completed_at&.iso8601
      }
    end
  end
end
