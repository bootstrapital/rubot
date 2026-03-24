# frozen_string_literal: true

require_relative "lib/rubot/version"

Gem::Specification.new do |spec|
  spec.name = "rubot"
  spec.version = Rubot::VERSION
  spec.authors = ["OpenAI Codex"]
  spec.email = ["support@example.com"]

  spec.summary = "Rails-native framework for agentic internal tools"
  spec.description = "Rubot provides agent, tool, and workflow primitives for building operator-facing AI workflows in Ruby and Rails."
  spec.homepage = "https://example.com/rubot"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  spec.files = Dir.glob(%w[
    README.md
    lib/**/*.rb
    examples/**/*.rb
  ])

  spec.require_paths = ["lib"]
  spec.add_dependency "json"
end
