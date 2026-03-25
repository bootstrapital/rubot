# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Rubot
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_initializer
        template "initializer.rb.tt", "config/initializers/rubot.rb"
      end

      def copy_migration
        migration_template "create_rubot_tables.rb.tt", "db/migrate/create_rubot_tables.rb"
      end

      def mount_engine
        route 'mount Rubot::Engine => "/rubot/admin"'
      end
    end
  end
end
