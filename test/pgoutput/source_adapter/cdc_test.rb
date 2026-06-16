# frozen_string_literal: true

require_relative '../../test_helper'

module Pgoutput
  module SourceAdapter
    # rubocop:disable Metrics/ClassLength
    class CdcTest < Minitest::Test
      Events = Pgoutput::Decoder::Events

      SyntheticInsert = Data.define(:transaction_id, :schema, :table, :values)
      SyntheticInsertWithoutRelation = Class.new(SyntheticInsert) do
        def self.name = 'Pgoutput::Decoder::Events::Insert'
      end

      def test_namespace_alias_points_to_source_adapter_namespace
        assert_same Pgoutput::SourceAdapter, Pgoutput::Source::Adapter
      end

      def test_version_number
        refute_nil Pgoutput::SourceAdapter::VERSION
      end

      # rubocop:disable Metrics/AbcSize
      def test_normalizes_insert_to_change_event
        event = Events::Insert.new(42, 7, 'public', 'users', { 'id' => 1, 'email' => 'ken@example.com' })

        change = Pgoutput::SourceAdapter::Cdc.new.normalize(event)

        assert_instance_of CDC::Core::ChangeEvent, change
        assert_predicate change, :insert?
        assert_equal 'public', change.schema
        assert_equal 'users', change.table
        assert_nil change.old_values
        assert_equal({ 'id' => 1, 'email' => 'ken@example.com' }, change.new_values)
        assert_equal({ 'id' => 1 }, change.primary_key)
        assert_equal 42, change.transaction_id
        assert_equal 'pgoutput', change.metadata['source']
        assert_equal 7, change.metadata['relation_id']
        assert_equal 'Insert', change.metadata['pgoutput_event']
      end
      # rubocop:enable Metrics/AbcSize

      def test_normalizes_insert_with_symbol_id_primary_key
        event = Events::Insert.new(42, 7, 'public', 'users', { id: 1, email: 'ken@example.com' })

        change = Pgoutput::SourceAdapter::Cdc.new.normalize(event)

        assert_equal({ 'id' => 1 }, change.primary_key)
      end

      def test_normalizes_insert_without_hash_like_values_or_relation_id
        event = SyntheticInsertWithoutRelation.new(42, 'public', 'users', nil)

        change = Pgoutput::SourceAdapter::Cdc.new.normalize(event)

        assert_nil change.primary_key
        assert_nil change.new_values
        refute_includes change.metadata, 'relation_id'
      end

      def test_normalizes_update_to_change_event_using_old_key_as_primary_key
        event = Events::Update.new(
          42,
          7,
          'public',
          'users',
          { 'id' => 1 },
          { 'email' => 'old@example.com' },
          { 'id' => 1, 'email' => 'new@example.com' }
        )

        change = Pgoutput::SourceAdapter::Cdc.new.normalize(event)

        assert_predicate change, :update?
        assert_equal({ 'email' => 'old@example.com' }, change.old_values)
        assert_equal({ 'id' => 1, 'email' => 'new@example.com' }, change.new_values)
        assert_equal({ 'id' => 1 }, change.primary_key)
      end

      def test_normalizes_update_using_old_key_as_old_values_when_old_values_is_absent
        event = Events::Update.new(
          42,
          7,
          'public',
          'users',
          { 'id' => 1 },
          nil,
          { 'id' => 1, 'email' => 'new@example.com' }
        )

        change = Pgoutput::SourceAdapter::Cdc.new.normalize(event)

        assert_equal({ 'id' => 1 }, change.old_values)
        assert_equal({ 'id' => 1 }, change.primary_key)
      end

      def test_normalizes_delete_to_change_event
        event = Events::Delete.new(
          42,
          7,
          'public',
          'users',
          { 'id' => 1 },
          { 'id' => 1, 'email' => 'old@example.com' }
        )

        change = Pgoutput::SourceAdapter::Cdc.new.normalize(event)

        assert_predicate change, :delete?
        assert_equal({ 'id' => 1, 'email' => 'old@example.com' }, change.old_values)
        assert_nil change.new_values
        assert_equal({ 'id' => 1 }, change.primary_key)
      end

      def test_normalizes_delete_using_old_key_when_old_values_is_absent
        event = Events::Delete.new(42, 7, 'public', 'users', { 'id' => 1 }, nil)

        change = Pgoutput::SourceAdapter::Cdc.new.normalize(event)

        assert_equal({ 'id' => 1 }, change.old_values)
        assert_equal({ 'id' => 1 }, change.primary_key)
      end

      def test_normalize_returns_nil_for_transaction_boundaries
        adapter = Pgoutput::SourceAdapter::Cdc.new

        assert_nil adapter.normalize(Events::Begin.new(42, 10, 123_456))
        assert_nil adapter.normalize(Events::Commit.new(42, 0, 11, 12, 123_789))
      end

      def test_normalize_raises_for_unknown_event
        error = assert_raises(Pgoutput::SourceAdapter::Error) do
          Pgoutput::SourceAdapter::Cdc.new.normalize(Object.new)
        end

        assert_match(/unsupported pgoutput decoded event/, error.message)
      end

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      def test_normalize_many_groups_transaction_boundaries_into_envelope
        adapter = Pgoutput::SourceAdapter::Cdc.new
        begin_event = Events::Begin.new(42, 10, 123_456)
        insert = Events::Insert.new(42, 7, 'public', 'users', { 'id' => 1 })
        commit = Events::Commit.new(42, 0, 11, 12, 123_789)

        results = adapter.normalize_many([begin_event, insert, commit])

        assert_equal 1, results.size
        envelope = results.first

        assert_instance_of CDC::Core::TransactionEnvelope, envelope
        assert_equal 42, envelope.transaction_id
        assert_equal '11', envelope.commit_lsn
        assert_equal 123_789, envelope.committed_at
        assert_equal 1, envelope.events.size
        assert_predicate envelope.events.first, :insert?
        assert_equal '10', envelope.metadata['begin_final_lsn']
        assert_equal 123_456, envelope.metadata['begin_commit_timestamp']
        assert_equal 0, envelope.metadata['commit_flags']
        assert_equal '12', envelope.metadata['transaction_end_lsn']
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

      def test_normalize_many_keeps_changes_unwrapped_when_commit_has_no_open_transaction
        adapter = Pgoutput::SourceAdapter::Cdc.new
        insert = Events::Insert.new(42, 7, 'public', 'users', { 'id' => 1 })
        commit = Events::Commit.new(99, 0, 11, 12, 123_789)

        results = adapter.normalize_many([insert, commit])

        assert_equal 1, results.size
        assert_instance_of CDC::Core::ChangeEvent, results.first
        assert_equal 42, results.first.transaction_id
      end

      def test_normalize_many_ignores_empty_commit_boundaries
        adapter = Pgoutput::SourceAdapter::Cdc.new
        commit = Events::Commit.new(42, 0, 11, 12, 123_789)

        assert_empty adapter.normalize_many([commit])
      end

      def test_normalize_many_returns_unwrapped_changes_without_transaction_boundaries
        adapter = Pgoutput::SourceAdapter::Cdc.new
        insert = Events::Insert.new(42, 7, 'public', 'users', { 'id' => 1 })
        results = adapter.normalize_many([insert])

        assert_equal 1, results.size
        assert_instance_of CDC::Core::ChangeEvent, results.first
      end

      def test_normalize_many_flushes_open_transaction_when_commit_is_missing
        adapter = Pgoutput::SourceAdapter::Cdc.new
        begin_event = Events::Begin.new(42, 10, 123_456)
        insert = Events::Insert.new(42, 7, 'public', 'users', { 'id' => 1 })

        results = adapter.normalize_many([begin_event, insert])

        assert_equal 1, results.size
        assert_instance_of CDC::Core::ChangeEvent, results.first
      end

      def test_custom_primary_key_resolver_and_metadata_builder
        adapter = Pgoutput::SourceAdapter::Cdc.new(
          primary_key_resolver: ->(_event, values) { { 'uuid' => values.fetch('uuid') } },
          metadata_builder: ->(_event) { { adapter: 'custom' } }
        )
        event = Events::Insert.new(42, 7, 'public', 'users', { 'uuid' => 'abc' })

        change = adapter.normalize(event)

        assert_equal({ 'uuid' => 'abc' }, change.primary_key)
        assert_equal 'custom', change.metadata['adapter']
      end

      def test_metadata_builder_result_is_coerced_to_hash_with_string_keys
        metadata = Data.define(:sink) do
          def to_h = { sink: sink }
        end
        adapter = Pgoutput::SourceAdapter::Cdc.new(metadata_builder: ->(_event) { metadata.new('webhook') })
        event = Events::Insert.new(42, 7, 'public', 'users', { 'id' => 1 })

        change = adapter.normalize(event)

        assert_equal 'webhook', change.metadata['sink']
      end

      def test_transaction_envelope_handles_nil_lsns
        adapter = Pgoutput::SourceAdapter::Cdc.new
        begin_event = Events::Begin.new(42, nil, 123_456)
        insert = Events::Insert.new(42, 7, 'public', 'users', { 'id' => 1 })
        commit = Events::Commit.new(42, 0, nil, nil, 123_789)

        envelope = adapter.normalize_many([begin_event, insert, commit]).first

        assert_nil envelope.commit_lsn
        assert_nil envelope.metadata['begin_final_lsn']
        assert_nil envelope.metadata['transaction_end_lsn']
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
