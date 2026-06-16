# frozen_string_literal: true

require_relative 'source_adapter/version'

module Pgoutput
  # Source adapters normalize decoded pgoutput events into downstream platform
  # event models.
  #
  # The pgoutput family remains independently useful outside the CDC Ecosystem.
  # This namespace leaves room for adapters targeting other change-event
  # platforms while providing {Pgoutput::SourceAdapter::Cdc} as the CDC
  # Ecosystem adapter.
  #
  # @api public
  module SourceAdapter
    # Raised when a decoded pgoutput event cannot be normalized.
    #
    # The adapter raises this error for event objects outside the supported
    # pgoutput decoder event family. Callers should treat it as a programming or
    # integration error rather than a transient transport failure.
    #
    # @api public
    class Error < StandardError; end
  end
end

require_relative 'source_adapter/cdc'
