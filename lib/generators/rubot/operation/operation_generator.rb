# frozen_string_literal: true

require "rails/generators/named_base"

module Rubot
  module Generators
    class OperationGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      def create_operation
        template "operation.rb.tt", File.join("app/operations", class_path, "#{file_name}_operation.rb")
      end
    end
  end
end
