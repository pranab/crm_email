class CrmEmailGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      # m.directory "lib"
      # m.template 'README', "README"
      m.directory "db/migrate"
      m.migration_template "migration.rb", 'db/migrate',
                           :migration_file_name => "create_emails"
      
    end
  end
end
