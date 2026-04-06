# frozen_string_literal: true

require_relative "../../helpers/rubot/ui_helper"

module Rubot
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    include Rubot::UiHelper

    layout "rubot/application"
    before_action :authorize_rubot_admin!
    helper_method :rubot_navigation, :rubot_breadcrumbs

    private

    def rubot_store
      Rubot.store
    end

    def authorize_rubot_admin!
      authorizer = Rubot.configuration.admin_authorizer
      return true unless authorizer

      authorizer.arity == 1 ? authorizer.call(self) : instance_exec(&authorizer)
    end

    def authorize_rubot_action!(action, run: nil, resource: nil)
      Rubot::Policy.authorize!(
        action:,
        run:,
        resource: resource,
        context: run&.context || {},
        controller: self
      )
    end

    def rubot_navigation
      [
        { label: "Dashboard", path: rubot.root_path, key: :dashboard },
        { label: "Runs", path: rubot.runs_path, key: :runs },
        { label: "Approvals", path: rubot.approvals_path, key: :approvals },
        { label: "Playground", path: rubot.playground_index_path, key: :playground }
      ]
    end

    def rubot_breadcrumbs
      crumbs = [{ label: "Admin", path: rubot.root_path }]

      case controller_name
      when "dashboard"
        crumbs << { label: "Dashboard", path: nil }
      when "runs"
        crumbs << { label: "Runs", path: rubot.runs_path }
        crumbs << { label: (@run&.name || params[:id]), path: nil } if action_name == "show"
      when "approvals"
        crumbs << { label: "Approvals", path: nil }
      when "playground"
        crumbs << { label: "Playground", path: nil }
      when "tool_calls"
        crumbs << { label: "Runs", path: rubot.runs_path }
        crumbs << { label: (@run&.name || params[:run_id]), path: rubot.run_path(params[:run_id]) }
        crumbs << { label: (@tool_call&.short_name || "Tool Call"), path: nil }
      else
        crumbs << { label: controller_name.to_s.humanize, path: nil }
      end

      crumbs
    end
  end
end
