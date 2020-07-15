
module BulkDataMethods

  # exception thrown when row data structures are inconsistent between rows in single call to {#create_many} or {#update_many}
  class BulkDataInconsistent < StandardError
    def initialize(model, table_name, expected_columns, found_columns, while_doing)
      super("#{model.name}: for table: #{table_name}; #{expected_columns} != #{found_columns}; #{while_doing}")
    end
  end

  module Mixin

    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods

      # BULK creation of many rows
      #
      # @example no options used
      #   rows = [
      #         { :name => 'Keith', :salary => 1000 },
      #         { :name => 'Alex', :salary => 2000 }
      #   ]
      #   Employee.create_many(rows)
      #
      # @example with :returning option to returns key value
      #   rows = [
      #         { :name => 'Keith', :salary => 1000 },
      #         { :name => 'Alex', :salary => 2000 }
      #   ]
      #   options = { :returning => [:id] }
      #   Employee.create_many(rows, options)
      #   [#<Employee id: 1>, #<Employee id: 2>]
      #
      # @example with :slice_size option (will generate two insert queries)
      #   rows = [
      #         { :name => 'Keith', :salary => 1000 },
      #         { :name => 'Alex', :salary => 2000 },
      #         { :name => 'Mark', :salary => 3000 }
      #   ]
      #   options = { :slice_size => 2 }
      #   Employee.create_many(rows, options)
      #
      # @param [Array<Hash>] rows ([]) data to be inserted into database
      # @param [Hash] options ({}) options for bulk inserts
      # @option options [Integer] :slice_size (1000) how many records will be created in a single SQL query
      # @option options [Boolean] :check_consitency (true) ensure some modicum of sanity on the incoming dataset, specifically: does each row define the same set of key/value pairs
      # @option options [Array or String] :returning (nil) list of fields to return.
      # @return [Array<Hash>] rows returned from DB as option[:returning] requests
      # @raise [BulkDataInconsistent] raised when key/value pairs between rows are inconsistent (check disabled with option :check_consistency)
      def create_many(rows, options = {})
        return [] if rows.blank?
        options[:slice_size] = 1000 unless options.has_key?(:slice_size)
        options[:check_consistency] = true unless options.has_key?(:check_consistency)
        returning_clause = ""
        if options[:returning]
          if options[:returning].is_a? Array
            returning_list = options[:returning].join(',')
          else
            returning_list = options[:returning]
          end
          returning_clause = " returning #{returning_list}"
        end
        returning = []

        created_at_value = Time.zone.now
        updated_at_value = created_at_value

        row_ids = []
        column_names = self.columns.map(&:name)
        has_id = column_names.include?("id")
        has_created_at = column_names.include?("created_at")
        has_updated_at = column_names.include?("updated_at")
        if has_id
          num_sequences_needed = rows.reject{|r| r[:id].present?}.length
          if num_sequences_needed > 0
            row_ids = connection.next_sequence_batch(sequence_name, num_sequences_needed)
          end
        end
        rows.each do |row|
          # set the primary key if it needs to be set
          if has_id
            row[:id] ||= row_ids.shift
          end
        end.each do |row|
          # set :created_at/:updated_at if need be
          if has_created_at
            row[:created_at] ||= created_at_value
          end
          if has_updated_at
            row[:updated_at] ||= updated_at_value
          end
        end.group_by do |row|
          respond_to?(:partition_table_name) ? partition_table_name(*partition_key_values(row)) : table_name
        end.each do |table_name, rows_for_table|
          column_names = rows_for_table[0].keys.sort{|a,b| a.to_s <=> b.to_s}
          sql_insert_string = "INSERT INTO #{table_name} (#{column_names.join(',')}) VALUES "
          rows_for_table.map do |row|
            if options[:check_consistency]
              row_column_names = row.keys.sort{|a,b| a.to_s <=> b.to_s}
              if column_names != row_column_names
                raise BulkDataInconsistent.new(self, table_name, column_names, row_column_names, "while attempting to build insert statement")
              end
            end
            column_values = column_names.map do |column_name|
              connection.quote(row[column_name])
            end.join(',')
            "(#{column_values})"
          end.each_slice(options[:slice_size]) do |insert_slice|
            sql = sql_insert_string + insert_slice.join(',') + returning_clause
#puts "SQL> #{sql}"            
            returning += find_by_sql(sql)
          end
        end
        return returning
      end

      #
      # BULK updates of many rows
      #
      # @return [Array<Hash>] rows returned from DB as option[:returning] requests
      # @raise [BulkDataInconsistent] raised when key/value pairs between rows are inconsistent (check disabled with option :check_consistency)
      # @param [Hash] options ({}) options for bulk inserts
      # @option options [Integer] :slice_size (1000) how many records will be created in a single SQL query
      # @option options [Boolean] :check_consitency (true) ensure some modicum of sanity on the incoming dataset, specifically: does each row define the same set of key/value pairs
      # @option options [Array] :returning (nil) list of fields to return.
      # @option options [String] :returning (nil) single field to return.
      #
      # @overload update_many(rows = [], options = {})
      #   @param [Array<Hash>] rows ([]) data to be updated
      #   @option options [String] :set_array (built from first row passed in) the set clause
      #   @option options [String] :where_datatable ('"#{table_name}.id = datatable.id"') the where clause specifying how to join the datatable against the real table
      #   @option options [String] :where_constraint the rest of the where clause that limits what rows of the table get updated
      #
      # @overload update_many(rows = {}, options = {})
      #   @param [Hash<Hash, Hash>] rows ({}) data to be updated
      #   @option options [String] :set_array (built from the values in the first key/value pair of `rows`) the set clause
      #   @option options [String] :where_datatable ('"#{table_name}.id = datatable.id"') the where clause specifying how to join the datatable against the real table
      #   @option options [String] :where_constraint the rest of the where clause that limits what rows of the table get updated
      #
      # @example using "set_array" to add the value of "salary" to the specific employee's salary the default where clause matches IDs so, it works here.
      #   rows = [
      #     { :id => 1, :salary => 1000 },
      #     { :id => 10, :salary => 2000 },
      #     { :id => 23, :salary => 2500 }
      #   ]
      #   options = { :set_array => '"salary = datatable.salary"' }
      #   Employee.update_many(rows, options)
      #
      # @example using where_datatable clause to match salary.
      #   rows = [
      #     { :id => 1, :salary => 1000, :company_id => 10 },
      #     { :id => 10, :salary => 2000, :company_id => 12 },
      #     { :id => 23, :salary => 2500, :company_id => 5 }
      #   ]
      #   options = {
      #     :set_array => '"salary = datatable.salary"',
      #     :where_constraint => '"#{table_name}.salary <> datatable.salary"'
      #   }
      #   Employee.update_many(rows, options)
      #
      # @example using where_constraint clause to only update salary for active employees
      #   rows = [
      #     { :id => 1, :salary => 1000, :company_id => 10 },
      #     { :id => 10, :salary => 2000, :company_id => 12 },
      #     { :id => 23, :salary => 2500, :company_id => 5 }
      #   ]
      #   options = {
      #     :set_array => '"salary = datatable.salary"',
      #     :where_constraint => '"#{table_name}.active = true"'
      #   }
      #   Employee.update_many(rows, options)
      #
      # @example setting where clause to the KEY of the hash passed in and the set_array is generated from the VALUES
      #   rows = {
      #     { :id => 1 } => { :salary => 100000, :company_id => 10 },
      #     { :id => 10 } => { :salary => 110000, :company_id => 12 },
      #     { :id => 23 } => { :salary => 90000, :company_id => 5 }
      #   }
      #   Employee.update_many(rows)
      #
      # @note Remember that you should probably set updated_at using "updated = datatable.updated_at"
      #   or "updated_at = now()" in the set_array if you want to follow
      #   the standard active record model for time columns (and you have an updated_at column)
      def update_many(rows, options = {})
        return [] if rows.blank?
        if rows.is_a?(Hash)
          options[:where_datatable] = '"' + rows.keys[0].keys.map{|key| '#{table_name}.' + "#{key} = datatable.#{key}"}.join(' and ') + '"'
          options[:set_array] = '"' + rows.values[0].keys.map{|key| "#{key} = datatable.#{key}"}.join(',') + '"' unless options[:set_array]
          r = []
          rows.each do |key,value|
            r << key.merge(value)
          end
          rows = r
        end
        unless options[:set_array]
          column_names =  rows[0].keys
          columns_to_remove = [:id]
          columns_to_remove += partition_keys.flatten.map{|k| k.to_sym} if respond_to?(:partition_keys)
          options[:set_array] = '"' + (column_names - columns_to_remove).map{|cn| "#{cn} = datatable.#{cn}"}.join(',') + '"'
        end
        options[:slice_size] = 1000 unless options[:slice_size]
        options[:check_consistency] = true unless options.has_key?(:check_consistency)
        returning_clause = ""
        if options[:returning]
          if options[:returning].is_a?(Array)
            returning_list = options[:returning].map{|r| '#{table_name}.' + r.to_s}.join(',')
          else
            returning_list = options[:returning]
          end
          returning_clause = "\" RETURNING #{returning_list}\""
        end
        where_clause = options[:where_datatable] || '"#{table_name}.id = datatable.id"'
        where_constraint = ""
        if options[:where_constraint]
          where_constraint = '" AND #{eval(options[:where_constraint])}"'
        end
        returning = []

        rows.group_by do |row|
          respond_to?(:partition_table_name) ? partition_table_name(*partition_key_values(row)) : table_name
        end.each do |table_name, rows_for_table|
          column_names = rows_for_table[0].keys.sort{|a,b| a.to_s <=> b.to_s}
          rows_for_table.each_slice(options[:slice_size]) do |update_slice|
            datatable_rows = []
            update_slice.each_with_index do |row,i|
              if options[:check_consistency]
                row_column_names = row.keys.sort{|a,b| a.to_s <=> b.to_s}
                if column_names != row_column_names
                  raise BulkDataInconsistent.new(self, table_name, column_names, row_column_names, "while attempting to build update statement")
                end
              end
              datatable_rows << row.map do |column_name,column_value|
                column_name = column_name.to_s
                columns_hash_value = columns_hash[column_name]
                if i == 0
                  "#{connection.quote(column_value)}::#{columns_hash_value.sql_type} as #{column_name}"
                else
                  connection.quote(column_value)
                end
              end.join(',')
            end
            datatable = datatable_rows.join(' UNION SELECT ')

            sql_update_string = <<-SQL
              UPDATE #{table_name} SET
                #{eval(options[:set_array])}
              FROM
              (SELECT
                #{datatable}
              ) AS datatable
              WHERE
                #{eval(where_clause)}
                #{eval(where_constraint)}
              #{eval(returning_clause)}
            SQL
            sql = sql_update_string
#puts "SQL> #{sql}"            
            returning += find_by_sql(sql_update_string)
          end
        end
        return returning
      end 

    end # ClassMethods

    module InstanceMethods
    end # InstanceMethods

  end # Mixin

end # BulkDataMethods
