require "bulk_data_methods/engine"
require 'bulk_data_methods/configuration'
require "bulk_data_methods/version"
require "bulk_data_methods/bulk_methods_mixin"
require "bulk_data_methods/monkey_patch_postgres"
require "bulk_data_methods/generic_bulk_insert_statement_builder"
require "bulk_data_methods/postgres_copy_statement_builder"

module BulkDataMethods

  class << self

    attr_writer :configuration

    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def statement_builder
      configuration.statement_builder.constantize
    end

    def slice_size
      configuration.slice_size
    end

    def check_consistency
      configuration.check_consistency
    end

    def returning
      configuration.returning
    end

  end

end
