# frozen_string_literal: true

require 'cdc/core'

unless CDC::Core.const_defined?(:SourceAdapter)
  raise LoadError, 'pgoutput-source-adapter requires a cdc-core version that defines CDC::Core::SourceAdapter'
end

module Pgoutput
  module SourceAdapter
    # Normalizes Pgoutput::Decoder::Events into CDC::Core primitives.
    #
    # This adapter is intentionally located under the Pgoutput namespace because
    # it adapts pgoutput decoded events. The target is CDC::Core, so this class
    # depends on cdc-core while the lower-level pgoutput-client, pgoutput-parser,
    # and pgoutput-decoder gems remain standalone.
    #
    # @example Normalize a decoded insert event
    #   adapter = Pgoutput::SourceAdapter::Cdc.new
    #   change_event = adapter.normalize(decoded_insert)
    #
    # @example Normalize a decoded transaction event batch
    #   envelope = adapter.normalize_many([begin_event, insert_event, commit_event]).first
    #
    # @api public
    class Cdc < CDC::Core::SourceAdapter
      SOURCE_NAME = 'pgoutput'

      # @param primary_key_resolver [#call, nil] optional callable used to infer
      #   primary keys from decoded row values when pgoutput does not provide an
      #   old-key tuple. The callable receives the decoded event and value hash.
      # @param metadata_builder [#call, nil] optional callable that can return
      #   extra metadata for each decoded event. Returned keys are stringified.
      # @return [void]
      def initialize(primary_key_resolver: nil, metadata_builder: nil)
        @primary_key_resolver = primary_key_resolver || method(:default_primary_key)
        @metadata_builder = metadata_builder
        super()
      end

      # Normalize one decoded pgoutput event.
      #
      # Transaction boundary events return nil because they do not represent a
      # row-level change by themselves. Use #normalize_many when transaction
      # envelopes are desired.
      #
      # @param event [Object] a Pgoutput::Decoder::Events object.
      # @return [CDC::Core::ChangeEvent, nil] normalized row change event, or
      #   nil for transaction boundary events.
      # @raise [Pgoutput::SourceAdapter::Error] when the decoded event type is
      #   unsupported.
      def normalize(event)
        case event_name(event)
        when 'Insert'
          change_event(
            event,
            operation: :insert,
            old_values: nil,
            new_values: event.values,
            primary_key: primary_key_for(event, event.values)
          )
        when 'Update'
          old_values = event.old_values || event.old_key

          change_event(
            event,
            operation: :update,
            old_values: old_values,
            new_values: event.new_values,
            primary_key: primary_key_for(event, event.new_values)
          )
        when 'Delete'
          old_values = event.old_values || event.old_key

          change_event(
            event,
            operation: :delete,
            old_values: old_values,
            new_values: nil,
            primary_key: primary_key_for(event, old_values)
          )
        when 'Begin', 'Commit'
          nil
        else
          raise Error, "unsupported pgoutput decoded event: #{event.class}"
        end
      end

      # Normalize a sequence of decoded pgoutput events.
      #
      # If the sequence contains transaction boundaries, row changes between a
      # Begin and Commit are grouped into CDC::Core::TransactionEnvelope. If no
      # transaction boundaries are present, row changes are returned individually.
      #
      # @param events [Enumerable<Object>] decoded pgoutput events.
      # @return [Array<CDC::Core::ChangeEvent, CDC::Core::TransactionEnvelope>]
      #   normalized row changes and transaction envelopes in input order.
      # @raise [Pgoutput::SourceAdapter::Error] when any decoded event type is
      #   unsupported.
      def normalize_many(events)
        results = [] #: Array[CDC::Core::ChangeEvent | CDC::Core::TransactionEnvelope]
        transaction_id = nil
        transaction_events = [] #: Array[CDC::Core::ChangeEvent]
        transaction_metadata = {} #: Hash[String, untyped]

        events.each do |event|
          case event_name(event)
          when 'Begin'
            transaction_id = event.transaction_id
            transaction_events = []
            transaction_metadata = metadata_for(event).merge(
              'begin_final_lsn' => lsn_string(event.final_lsn),
              'begin_commit_timestamp' => event.commit_timestamp
            )
          when 'Commit'
            if transaction_id || !transaction_events.empty?
              results << transaction_envelope(
                event,
                transaction_id: transaction_id || event.transaction_id,
                events: transaction_events,
                metadata: transaction_metadata
              )
            end

            transaction_id = nil
            transaction_events = []
            transaction_metadata = {}
          else
            normalized = normalize(event)
            next if normalized.nil?

            if transaction_id
              transaction_events << normalized
            else
              results << normalized
            end
          end
        end

        results.concat(transaction_events) if transaction_id && !transaction_events.empty?
        share(results.freeze)
      end

      private

      attr_reader :primary_key_resolver, :metadata_builder

      def change_event(event, operation:, old_values:, new_values:, primary_key:)
        share(
          CDC::Core::ChangeEvent.new(
            operation: operation,
            schema: event.schema,
            table: event.table,
            old_values: old_values,
            new_values: new_values,
            primary_key: primary_key,
            transaction_id: event.transaction_id,
            metadata: metadata_for(event)
          )
        )
      end

      def transaction_envelope(event, transaction_id:, events:, metadata:)
        share(
          CDC::Core::TransactionEnvelope.new(
            transaction_id: transaction_id,
            events: events.freeze,
            commit_lsn: lsn_string(event.commit_lsn),
            committed_at: event.commit_timestamp,
            metadata: metadata.merge(metadata_for(event)).merge(
              'commit_flags' => event.flags,
              'transaction_end_lsn' => lsn_string(event.transaction_end_lsn)
            )
          )
        )
      end

      def primary_key_for(event, values)
        return event.old_key if event.respond_to?(:old_key) && event.old_key

        primary_key_resolver.call(event, values)
      end

      def default_primary_key(_event, values)
        return nil unless values.respond_to?(:key?)

        if values.key?('id')
          { 'id' => values['id'] }
        elsif values.key?(:id)
          { 'id' => values[:id] }
        end
      end

      def metadata_for(event)
        metadata = {
          'source' => SOURCE_NAME,
          'relation_id' => relation_id_for(event),
          'pgoutput_event' => event_name(event)
        }
        extra = metadata_builder&.call(event)
        metadata.merge!(stringify_keys(extra)) if extra
        compact(metadata)
      end

      def relation_id_for(event)
        event.relation_id if event.respond_to?(:relation_id)
      end

      def event_name(event)
        event.class.name.split('::').last
      end

      def lsn_string(lsn)
        lsn&.to_s
      end

      def stringify_keys(hash)
        hash.to_h.transform_keys(&:to_s)
      end

      def compact(hash)
        hash.compact
      end

      def share(object)
        Ractor.make_shareable(object)
      rescue Ractor::Error
        object
      end
    end
  end
end
