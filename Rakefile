require 'bundler/setup'
require 'rake/testtask'
require "bump/tasks"
require "bundler/gem_tasks"

task default: [:spec]

Rake::TestTask.new :spec do |t|
  t.test_files = FileList['spec/**/*_spec.rb']
end
