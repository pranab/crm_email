# desc "Explaining what the task does"
namespace :crm_email do
  # load crm_email settings
  namespace :settings do
    desc "Load crm_email plugin  settings"
    task :load => :environment do
      ActiveRecord::Base.establish_connection(Rails.env)
      settings = YAML.load_file("#{RAILS_ROOT}/vendor/plugins/crm_email/config/settings.yml")
      settings.keys.each do |key|
        sql = [ "INSERT INTO settings (name, default_value) VALUES(?, ?)", key.to_s, Base64.encode64(Marshal.dump(settings[key])) ]
        sql = if Rails::VERSION::STRING < "2.3.3"
          ActiveRecord::Base.send(:sanitize_sql, sql)
        else
          ActiveRecord::Base.send(:sanitize_sql, sql, nil) # Rails 2.3.3 introduces extra "table_name" parameter.
        end
        ActiveRecord::Base.connection.execute(sql)
      end
    end

    desc "Re load crm_email plugin  settings"
    task :reload => :environment do
      ActiveRecord::Base.establish_connection(Rails.env)
      settings = YAML.load_file("#{RAILS_ROOT}/vendor/plugins/crm_email/config/settings.yml")
      settings.keys.each do |key|
        sql = [ "UPDATE  settings SET default_value = ? WHERE name = ?", Base64.encode64(Marshal.dump(settings[key])), key.to_s]
        sql = if Rails::VERSION::STRING < "2.3.3"
          ActiveRecord::Base.send(:sanitize_sql, sql)
        else
          ActiveRecord::Base.send(:sanitize_sql, sql, nil) # Rails 2.3.3 introduces extra "table_name" parameter.
        end
        ActiveRecord::Base.connection.execute(sql)
      end
    end

  end
  
end


