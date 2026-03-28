# frozen_string_literal: true

# 1. Model for State Persistence
# rails generate model DisputeRun status:string input:json state:json events:json
class DisputeRun < ActiveRecord::Base
  serialize :input, JSON
  serialize :state, JSON
  serialize :events, JSON

  def add_event(name, data = {})
    self.events ||= []
    self.events << { timestamp: Time.now, name: name, data: data }
    save!
  end
end

# 2. Background Job for Async Execution
class ResolveDisputeJob < ApplicationJob
  queue_as :default

  def perform(run_id)
    run = DisputeRun.find(run_id)
    ResolveBillingDisputeService.new(run: run).call
  end
end

# 3. Controller for Human-in-the-loop (Approval)
class DisputeApprovalsController < ApplicationController
  def update
    @run = DisputeRun.find(params[:id])
    
    if params[:decision] == "approve"
      @run.update!(status: "approved")
      @run.add_event("approval.granted", by: current_user.email)
      
      # Manually re-trigger the service to finish
      ResolveBillingDisputeService.new(run: @run).finalize
      render json: { status: "completed" }
    else
      @run.update!(status: "rejected")
      render json: { status: "terminated" }
    end
  end
end

# 4. The Service Object (Expanded with Event Tracking)
class ResolveBillingDisputeService
  def initialize(run:)
    @run = run
  end

  def call
    @run.add_event("run.started")
    
    # Procedural fetching
    invoice = BillingSystem.fetch(@run.input["invoice_id"])
    usage = TelemetrySystem.fetch(@run.input["customer_id"])
    @run.update!(state: { invoice: invoice, usage: usage })
    @run.add_event("data.fetched")

    # Call LLM
    analysis = OpenAI::Client.new.chat(...) 
    @run.update!(state: @run.state.merge(analysis: analysis))

    # Manual Policy Check
    if analysis[:suggested_credit] > 100
      @run.update!(status: "awaiting_approval")
      @run.add_event("approval.requested")
      return
    end

    finalize
  end

  def finalize
    # Final execution
    BillingSystem.issue_credit(amount: @run.state[:analysis][:suggested_credit])
    @run.update!(status: "completed")
    @run.add_event("run.completed")
  end
end
