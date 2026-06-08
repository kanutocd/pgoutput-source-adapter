# pgoutput-source-adapter

`pgoutput-source-adapter` adapts decoded pgoutput events into downstream change-event platform primitives.

The first supported target is the CDC Ecosystem:

```ruby
Pgoutput::SourceAdapter::Cdc
```

It normalizes `Pgoutput::Decoder::Events` into `CDC::Core::ChangeEvent` and `CDC::Core::TransactionEnvelope` objects.

## Boundary

The pgoutput family remains standalone:

```text
pgoutput-client   -> PostgreSQL logical replication transport
pgoutput-parser   -> pgoutput protocol messages
pgoutput-decoder  -> typed Ruby row-change events
```

This gem is the adapter layer:

```text
Pgoutput::Decoder::Events
        |
        v
Pgoutput::SourceAdapter::Cdc
        |
        v
CDC::Core::ChangeEvent / TransactionEnvelope
```

That keeps the lower-level pgoutput gems usable outside the CDC Ecosystem while still providing a clean bridge into `cdc-core` for users building CDC platforms.

## Installation

```ruby
gem "pgoutput-source-adapter"
```

```ruby
require "pgoutput/source_adapter"
```

The generated `bundle gem` require path also works:

```ruby
require "pgoutput/source/adapter"
```

## Usage

Normalize a decoded insert event:

```ruby
adapter = Pgoutput::SourceAdapter::Cdc.new
change_event = adapter.normalize(decoded_insert)

change_event.operation
# => :insert

change_event.schema
change_event.table
change_event.new_values
```

Normalize a transaction-shaped batch:

```ruby
results = adapter.normalize_many([
  decoded_begin,
  decoded_insert,
  decoded_update,
  decoded_commit
])

envelope = results.first
# => CDC::Core::TransactionEnvelope
```

## Primary keys

For update and delete events, pgoutput may provide an old-key tuple. When it does, that tuple is used as the `CDC::Core::ChangeEvent#primary_key`.

For insert events, or for sources without old-key tuples, the adapter defaults to `id` / `"id"` when present.

You can provide your own resolver:

```ruby
adapter = Pgoutput::SourceAdapter::Cdc.new(
  primary_key_resolver: ->(_event, values) { { "uuid" => values.fetch("uuid") } }
)
```

## Metadata

Each normalized event includes pgoutput metadata:

```ruby
{
  "source" => "pgoutput",
  "relation_id" => 123,
  "pgoutput_event" => "Insert"
}
```

Additional metadata can be injected:

```ruby
adapter = Pgoutput::SourceAdapter::Cdc.new(
  metadata_builder: ->(_event) { { pipeline: "default" } }
)
```

## Public namespace

```ruby
Pgoutput::SourceAdapter
Pgoutput::SourceAdapter::Cdc
```

A compatibility alias is also provided for the generated gem path:

```ruby
Pgoutput::Source::Adapter
```

## Non-goals

This gem does not:

- connect to PostgreSQL
- parse pgoutput protocol messages
- decode PostgreSQL values
- run processors
- manage replication slots
- persist sink data

Those responsibilities belong to `pgoutput-client`, `pgoutput-parser`, `pgoutput-decoder`, runtime gems, or application code.

## Development

```bash
bundle exec rake
```

## License

MIT.
