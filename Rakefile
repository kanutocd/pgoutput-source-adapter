# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'
require 'yard'

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
end

RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = ['--parallel']
end

YARD::Rake::YardocTask.new(:yard)

desc 'Validate rbs sig files'
task :steep do
  sh 'bundle exec steep check'
end

desc 'Open coverage report'
task :coverage do
  sh 'xdg-open coverage/index.html'
end

task default: %i[test rubocop steep yard]
