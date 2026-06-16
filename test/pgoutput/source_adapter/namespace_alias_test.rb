# frozen_string_literal: true

require_relative '../../test_helper'
require 'pgoutput/source/adapter'

module Pgoutput
  module SourceAdapter
    class NamespaceAliasTest < Minitest::Test
      def test_source_adapter_alias_points_to_public_namespace
        assert_same Pgoutput::SourceAdapter, Pgoutput::Source::Adapter
      end
    end
  end
end
