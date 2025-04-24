# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = 'spec/**/*_spec.rb'
  task.verbose = false
end

require 'rubocop/rake_task'
RuboCop::RakeTask.new do |task|
  task.patterns << 'lib/**/*.rb'
  task.verbose = true
  task.options = ['--format', 'progress']
end

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'spec'
  t.libs << 'lib'
  t.test_files = FileList['spec/**/*_spec.rb']
end

task default: %i[rubocop:autocorrect_all spec]
