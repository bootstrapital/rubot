# frozen_string_literal: true

require_relative "../../helpers/rubot/ui_helper"

module Rubot
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    include Rubot::UiHelper

    layout "rubot/application"
    before_action :authorize_rubot_admin!
    helper_method :rubot_navigation

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
  end
end
