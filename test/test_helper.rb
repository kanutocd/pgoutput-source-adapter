# frozen_string_literal: true

require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.start do
  enable_coverage :branch
  track_files 'lib/**/*.rb'

  add_filter '/test/'
  add_filter '/sig/'
  add_filter '/vendor/'
  add_filter '/version.rb'

  minimum_coverage line: 95
  minimum_coverage branch: 90

  formatter SimpleCov::Formatter::MultiFormatter.new([
                                                       SimpleCov::Formatter::HTMLFormatter,
                                                       SimpleCov::Formatter::CoberturaFormatter
                                                     ])
end

$LOAD_PATH.unshift File.expand_path('support', __dir__)
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'pgoutput/decoder/events'
require 'pgoutput/source_adapter'
require 'minitest/autorun'
