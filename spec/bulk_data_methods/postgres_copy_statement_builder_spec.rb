require 'spec_helper'
require "#{File.dirname(__FILE__)}/../support/tables_spec_helper"

describe "PostgresCopyStatementBuilder" do
  include TablesSpecHelper

  before do
    class Employee < ActiveRecord::Base
      extend BulkMethodsMixin
    end
    create_tables
  end

  let!(:subject) { ::BulkDataMethods::PostgresCopyStatementBuilder }
  let!(:options) { Employee.set_options(:statement_builder => 'BulkDataMethods::PostgresCopyStatementBuilder') }

  describe "#create_many" do

    context "when file doesn't exist" do
      it "returns empty array" do
        subject.create_many(
                             "/fake_path",
                             options,
                             Employee
                           ).should == []
      end
    end # when file doesn't exist

  end # #create_many

end # PostgresCopyStatementBuilder