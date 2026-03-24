# frozen_string_literal: true

require "rails/generators/named_base"

module Rubot
  module Generators
    class ToolGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      def create_tool
        template "tool.rb.tt", File.join("app/tools", class_path, "#{file_name}.rb")
      end
    end
  end
end
