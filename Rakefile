# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new

# so both `bundle exec rake yard` and `bundle exec yard doc` fetch options from ./.yardopts
YARD::Rake::YardocTask.new(:yard)

task default: %i[test rubocop yard]

namespace :rbs do 
  desc 'Generate RBS signatures'
  task :gen do    
    sh 'bundle exec rbs prototype rb --out-dir=sig --base-dir=lib lib'
  end

  desc "Destructively delete all signature files"
  task :clobber do
    sh 'rm -rf sig'
  end

  desc 'Validate RBS signatures'
  task :validate do
    sh 'bundle exec steep check'
  end  
end
