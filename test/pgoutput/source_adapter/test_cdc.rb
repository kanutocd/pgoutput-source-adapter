# frozen_string_literal: true

require "test_helper"

class Pgoutput::SourceAdapter::TestCdc < Minitest::Test
  Events = Pgoutput::Decoder::Events

  def test_version_number
    refute_nil Pgoutput::SourceAdapter::VERSION
  end

  def test_normalizes_insert_to_change_event
    event = Events::Insert.new(42, 7, "public", "users", { "id" => 1, "email" => "ken@example.com" })

    change = Pgoutput::SourceAdapter::Cdc.new.normalize(event)

    assert_instance_of CDC::Core::ChangeEvent, change
    assert_predicate change, :insert?
    assert_equal "public", change.schema
    assert_equal "users", change.table
    assert_nil change.old_values
    assert_equal({ "id" => 1, "email" => "ken@example.com" }, change.new_values)
    assert_equal({ "id" => 1 }, change.primary_key)
    assert_equal 42, change.transaction_id
    assert_equal "pgoutput", change.metadata["source"]
    assert_equal 7, change.metadata["relation_id"]
    assert_equal "Insert", change.metadata["pgoutput_event"]
  end

  def test_normalizes_update_to_change_event_using_old_key_as_primary_key
    event = Events::Update.new(
      42,
      7,
      "public",
      "users",
      { "id" => 1 },
      { "email" => "old@example.com" },
      { "id" => 1, "email" => "new@example.com" }
    )

    change = Pgoutput::SourceAdapter::Cdc.new.normalize(event)

    assert_predicate change, :update?
    assert_equal({ "email" => "old@example.com" }, change.old_values)
    assert_equal({ "id" => 1, "email" => "new@example.com" }, change.new_values)
    assert_equal({ "id" => 1 }, change.primary_key)
  end

  def test_normalizes_delete_to_change_event
    event = Events::Delete.new(
      42,
      7,
      "public",
      "users",
      { "id" => 1 },
      { "id" => 1, "email" => "old@example.com" }
    )

    change = Pgoutput::SourceAdapter::Cdc.new.normalize(event)

    assert_predicate change, :delete?
    assert_equal({ "id" => 1, "email" => "old@example.com" }, change.old_values)
    assert_nil change.new_values
    assert_equal({ "id" => 1 }, change.primary_key)
  end

  def test_normalize_many_groups_transaction_boundaries_into_envelope
    adapter = Pgoutput::SourceAdapter::Cdc.new
    begin_event = Events::Begin.new(42, 10, 123_456)
    insert = Events::Insert.new(42, 7, "public", "users", { "id" => 1 })
    commit = Events::Commit.new(42, 0, 11, 12, 123_789)

    results = adapter.normalize_many([begin_event, insert, commit])

    assert_equal 1, results.size
    envelope = results.first
    assert_instance_of CDC::Core::TransactionEnvelope, envelope
    assert_equal 42, envelope.transaction_id
    assert_equal "11", envelope.commit_lsn
    assert_equal 123_789, envelope.committed_at
    assert_equal 1, envelope.events.size
    assert_predicate envelope.events.first, :insert?
  end

  def test_custom_primary_key_resolver_and_metadata_builder
    adapter = Pgoutput::SourceAdapter::Cdc.new(
      primary_key_resolver: ->(_event, values) { { "uuid" => values.fetch("uuid") } },
      metadata_builder: ->(_event) { { adapter: "custom" } }
    )
    event = Events::Insert.new(42, 7, "public", "users", { "uuid" => "abc" })

    change = adapter.normalize(event)

    assert_equal({ "uuid" => "abc" }, change.primary_key)
    assert_equal "custom", change.metadata["adapter"]
  end
end
