# frozen_string_literal: true

module CDC
  module Core
    class SourceAdapter
      def initialize(*) = nil
      def normalize(_payload) = raise NotImplementedError
      def normalize_many(payloads) = payloads.map { |payload| normalize(payload) }
    end

    class ChangeEvent
      attr_reader :operation, :schema, :table, :old_values, :new_values, :primary_key,
                  :transaction_id, :commit_lsn, :sequence_number, :occurred_at, :metadata

      def initialize(operation:, schema:, table:, old_values: nil, new_values: nil, primary_key: nil,
                     transaction_id: nil, commit_lsn: nil, sequence_number: nil, occurred_at: nil,
                     metadata: {})
        @operation = operation.to_sym
        @schema = schema
        @table = table
        @old_values = old_values
        @new_values = new_values
        @primary_key = primary_key
        @transaction_id = transaction_id
        @commit_lsn = commit_lsn
        @sequence_number = sequence_number
        @occurred_at = occurred_at
        @metadata = metadata
      end

      def insert? = operation == :insert
      def update? = operation == :update
      def delete? = operation == :delete
    end

    class TransactionEnvelope
      attr_reader :transaction_id, :events, :commit_lsn, :committed_at, :metadata

      def initialize(transaction_id:, events:, commit_lsn: nil, committed_at: nil, metadata: {})
        @transaction_id = transaction_id
        @events = events
        @commit_lsn = commit_lsn
        @committed_at = committed_at
        @metadata = metadata
      end
    end
  end
end
