module BulkDataMethods
  class Configuration
    attr_accessor :statement_builder, :slice_size, :check_consistency, :returning

    def initialize
      @check_consistency = true
      @returning = nil
    end

  end
end