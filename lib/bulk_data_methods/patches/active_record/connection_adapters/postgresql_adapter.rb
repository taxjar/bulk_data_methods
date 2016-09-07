require 'active_record'
require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/postgresql_adapter'
require 'active_record/connection_adapters/postgresql/quoting'

module ActiveRecord

  module ConnectionAdapters
    module PostgreSQL
      module Quoting

        private
        # ****** BEGIN PATCH ******
        # when column of postgresql is an array, call super and fail. for example with [2] or ["2"].
        # add condition for array elswhere call super
        # @param [Value]
        def _quote(value)
          case value
            when Array      then "'{#{value.join(',')}}'"
            else
              super
          end
        end
      end
    end
    # Patches extending the postgres adapter with new operations for managing
    # sequences (and sets of sequence values).
    #
    class PostgreSQLAdapter < AbstractAdapter

      # ****** BEGIN PATCH ******
      # Get the next value in a sequence. Used on INSERT operation for
      # partitioning like by_id because the ID is required before the insert
      # so that the specific child table is known ahead of time.
      #
      # @param [String] sequence_name the name of the sequence to fetch the next value from
      # @return [Integer] the value from the sequence
      def next_sequence_value(sequence_name)
        return execute("SELECT NEXTVAL('#{sequence_name}')").field_values("nextval").first.to_i
      end
      # ****** END PATCH ******

      # ****** BEGIN PATCH ******
      # Get the some next values in a sequence.
      #
      # @param [String] sequence_name the name of the sequence to fetch the next values from
      # @param [Integer] batch_size count of values.
      # @return [Array<Integer>] an array of values from the sequence
      def next_sequence_batch(sequence_name, batch_size)
        return execute("SELECT NEXTVAL('#{sequence_name}') FROM GENERATE_SERIES(1, #{batch_size})").field_values("nextval").map(&:to_i)
      end
      # ****** END PATCH ******

    end # PostgreSQLAdapter

  end # ConnectionAdapters

end # ActiveRecord
