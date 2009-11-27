# Email plugin for Fat Free CRM
# Copyright (C) 2009-2010 by Pranab Ghosh
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#------------------------------------------------------------------------------
require "fat_free_crm"

FatFreeCRM::Plugin.register(:crm_email, initializer) do
          name "Fat Free Email Daemon"
        author "Pranab Ghosh"
       version "1.0.0"
   description "IMAP client for searching and fetching emails"
  dependencies :haml, :simple_column_search
end

require 'email_init'