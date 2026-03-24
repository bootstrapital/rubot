# frozen_string_literal: true

class HomeController < ApplicationController
  def show
    @available_operations = [
      {
        name: "Resume Screener",
        path: resume_screener_path,
        description: "Compare uploaded resumes against curated job descriptions and open the resulting Rubot run in admin."
      }
    ]
    @recent_runs = Rubot.store.all_runs.first(5)
    @pending_approvals = Rubot.store.pending_approvals.first(5)
  end
end
