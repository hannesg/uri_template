require "bundler/gem_tasks"

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |tx|
  tx.rspec_opts = ["-c", "-f progress", "-r ./spec/helper.rb"]
end
task :default => :spec
