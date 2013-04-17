BulkDataMethods.configure do |config|
  # a class that builds the current insert statement
  config.statement_builder = "::BulkDataMethods::GenericBulkInsertStatementBuilder"
  # how many records will be created in a single SQL query
  config.slice_size = 1000
end

