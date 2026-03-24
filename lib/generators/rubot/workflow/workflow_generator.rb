# frozen_string_literal: true

require "rails/generators/named_base"

module Rubot
  module Generators
    class WorkflowGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      def create_workflow
        template "workflow.rb.tt", File.join("app/workflows", class_path, "#{file_name}_workflow.rb")
      end
    end
  end
end
