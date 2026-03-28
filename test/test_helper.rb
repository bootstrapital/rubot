# frozen_string_literal: true

require 'simplecov'

# Use the SimpleFormatter by default to avoid noisy file-contention warnings
# during focused or concurrent test runs. For a rich HTML coverage report locally,
# run tests with `COVERAGE=true bundle exec rake test`.
if ENV['COVERAGE'] == 'true'
  require 'simplecov-html'
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
else
  SimpleCov.formatter = SimpleCov::Formatter::SimpleFormatter
end

SimpleCov.start

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "minitest/autorun"
require "rubot"
