require 'rails/generators'

class BulkDataMethodsGenerator < Rails::Generators::Base

  source_root File.expand_path("../templates", __FILE__)

  def add_configuration_files
    filename = "bulk_data_methods.rb"
    filepath = "config/initializers/#{filename}"
    path = "#{Rails.root}/#{filepath}"
    if File.exists?(path)
      puts "Skipping #{filepath} creation, as file already exists!"
    else
      puts "Adding Bulk Data Methods initializer (#{filepath})..."
      template filename, path
    end
  end

end
