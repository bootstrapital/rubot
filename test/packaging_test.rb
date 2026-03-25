# frozen_string_literal: true

require_relative "test_helper"
require "rubygems"

class PackagingTest < Minitest::Test
  def test_gemspec_includes_engine_runtime_files
    spec = Gem::Specification.load(File.expand_path("../rubot.gemspec", __dir__))

    assert_includes spec.files, "app/controllers/rubot/application_controller.rb"
    assert_includes spec.files, "app/views/layouts/rubot/application.html.erb"
    assert_includes spec.files, "app/assets/stylesheets/rubot/application.css"
    assert_includes spec.files, "config/routes.rb"
  end
end
