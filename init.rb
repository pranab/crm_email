# Include hook code here
require "fat_free_crm"

FatFreeCRM::Plugin.register(:crm_email, initializer) do
          name "Fat Free Email Daemon"
        author "Pranab Ghosh"
       version "1.0.0"
   description "IMAP client for searching and fetching emails"
  dependencies :haml, :simple_column_search
end
