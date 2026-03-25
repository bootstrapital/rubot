# frozen_string_literal: true

module Rubot
  module LiveUpdates
    class << self
      def enabled?
        feature_enabled?(:admin_live_updates) && defined?(Turbo::StreamsChannel) && defined?(Rubot::ApplicationController)
      end

      def broadcast_run(run)
        Broadcaster.new.broadcast_run(run)
      end

      def runs_stream_name
        "rubot:runs"
      end

      def approvals_stream_name
        "rubot:approvals"
      end

      def run_stream_name(run_id)
        "rubot:run:#{run_id}"
      end

      def runs_table_dom_id
        "rubot_runs_content"
      end

      def approvals_inbox_dom_id
        "rubot_approvals_content"
      end

      def run_overview_dom_id(run_id)
        "rubot_run_overview_#{run_id}"
      end

      def run_output_dom_id(run_id)
        "rubot_run_output_#{run_id}"
      end

      def run_pending_approval_dom_id(run_id)
        "rubot_run_pending_approval_#{run_id}"
      end

      def run_timeline_dom_id(run_id)
        "rubot_run_timeline_#{run_id}"
      end

      private

      def feature_enabled?(name)
        Rubot.configuration.features.fetch(name.to_sym, true)
      end
    end

    class Broadcaster
      def broadcast_run(run)
        return unless enabled?

        current_run = Rubot.store.find_run(run.id) || run
        presenter = Presenters::RunPresenter.new(current_run)

        broadcast_replace_to(
          LiveUpdates.runs_stream_name,
          target: LiveUpdates.runs_table_dom_id,
          html: render("rubot/runs/index_content", runs: all_run_presenters)
        )

        broadcast_replace_to(
          LiveUpdates.approvals_stream_name,
          target: LiveUpdates.approvals_inbox_dom_id,
          html: render("rubot/approvals/index_content", approvals: pending_approval_presenters)
        )

        broadcast_replace_to(
          LiveUpdates.run_stream_name(run.id),
          target: LiveUpdates.run_overview_dom_id(run.id),
          html: render("rubot/runs/overview", run: presenter)
        )

        broadcast_replace_to(
          LiveUpdates.run_stream_name(run.id),
          target: LiveUpdates.run_output_dom_id(run.id),
          html: render("rubot/runs/output", run: presenter)
        )

        broadcast_replace_to(
          LiveUpdates.run_stream_name(run.id),
          target: LiveUpdates.run_pending_approval_dom_id(run.id),
          html: render("rubot/runs/pending_approval", run: presenter)
        )

        broadcast_replace_to(
          LiveUpdates.run_stream_name(run.id),
          target: LiveUpdates.run_timeline_dom_id(run.id),
          html: render("rubot/runs/timeline", run: presenter)
        )
      end

      def enabled?
        LiveUpdates.enabled?
      end

      private

      def all_run_presenters
        Rubot.store.all_runs.map { |run| Presenters::RunPresenter.new(run) }
      end

      def pending_approval_presenters
        Rubot.store.pending_approvals.flat_map do |run|
          run.approvals.select(&:pending?).map do |approval|
            Presenters::ApprovalPresenter.new(run, approval)
          end
        end
      end

      def render(partial, locals)
        Rubot::ApplicationController.renderer.render(partial:, locals:)
      end

      def broadcast_replace_to(stream, target:, html:)
        Turbo::StreamsChannel.broadcast_replace_to(stream, target:, html:)
      end
    end
  end
end
