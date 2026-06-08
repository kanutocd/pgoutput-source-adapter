# frozen_string_literal: true

require_relative "source_adapter/version"

module Pgoutput
  # Source adapters normalize pgoutput decoded events into downstream platform
  # event models.
  #
  # The pgoutput family remains independently useful outside the CDC Ecosystem.
  # This namespace leaves room for adapters targeting other change-event
  # platforms while providing Pgoutput::SourceAdapter::Cdc as the CDC Ecosystem
  # adapter.
  module SourceAdapter
    class Error < StandardError; end
  end
end

require_relative "source_adapter/cdc"
