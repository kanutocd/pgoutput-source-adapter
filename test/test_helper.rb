# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("support", __dir__)
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "pgoutput/decoder/events"
require "pgoutput/source_adapter"
require "minitest/autorun"
