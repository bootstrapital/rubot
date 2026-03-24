# frozen_string_literal: true

require "rails/generators/named_base"

module Rubot
  module Generators
    class AgentGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      def create_agent
        template "agent.rb.tt", File.join("app/agents", class_path, "#{file_name}_agent.rb")
      end
    end
  end
end
