# frozen_string_literal: true

module Pgoutput
  class Decoder
    module Events
      Begin = Data.define(:transaction_id, :final_lsn, :commit_timestamp)
      Commit = Data.define(:transaction_id, :flags, :commit_lsn, :transaction_end_lsn, :commit_timestamp)
      Insert = Data.define(:transaction_id, :relation_id, :schema, :table, :values)
      Update = Data.define(:transaction_id, :relation_id, :schema, :table, :old_key, :old_values, :new_values)
      Delete = Data.define(:transaction_id, :relation_id, :schema, :table, :old_key, :old_values)
    end
  end
end
