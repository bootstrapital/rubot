require "rake/testtask"
require_relative "lib/rubot"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
end

load File.expand_path("lib/tasks/rubot_eval.rake", __dir__)

task default: :test
