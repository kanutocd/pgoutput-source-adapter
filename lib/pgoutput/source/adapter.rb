# frozen_string_literal: true

require_relative '../source_adapter'

module Pgoutput
  module Source
    # Compatibility alias for {Pgoutput::SourceAdapter}.
    #
    # This alias preserves the generated bundle-gem path shape while the public
    # adapter API lives under {Pgoutput::SourceAdapter}.
    #
    # @api public
    Adapter = Pgoutput::SourceAdapter
  end
end
