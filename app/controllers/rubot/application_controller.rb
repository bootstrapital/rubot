# frozen_string_literal: true

module Rubot
  class ApplicationController < ActionController::Base
    layout "application"

    private

    def rubot_store
      Rubot.store
    end
  end
end
