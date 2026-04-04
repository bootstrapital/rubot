# frozen_string_literal: true

require_relative "lib/rubot/version"

Gem::Specification.new do |spec|
  spec.name = "rubot"
  spec.version = Rubot::VERSION
  spec.authors = ["Chris Davis"]
  spec.email = ["chris@bootstrapital.com"]

  spec.summary = "Rails-native framework for agentic internal tools"
  spec.description = "Rubot provides agent, tool, and workflow primitives for building operator-facing AI workflows in Ruby and Rails."
  spec.homepage = "https://rubot.pdt.dev"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  spec.files = Dir.glob(%w[
    README.md
    app/**/*
    config/routes.rb
    lib/**/*.rb
    examples/**/*.rb
  ])

  spec.require_paths = ["lib"]
  spec.add_dependency "json", ">= 2.19.2"
  spec.add_dependency "activesupport"
  spec.add_dependency "faraday", ">= 2.14"
  spec.add_dependency "globalid"
  spec.add_development_dependency "actionpack"
  spec.add_development_dependency "activejob"
  spec.add_development_dependency "activerecord"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "railties"
end
