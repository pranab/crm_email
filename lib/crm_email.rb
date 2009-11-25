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

require 'task_executor'
require 'email_task'
  
  #start task executor daemon
  TaskExecutor.start()

  imap_setting = Setting[:email_imap]
  schedule = imap_setting[:mode] == "prod" ? imap_setting[:schedule] : "1m"
  
  #schedule email task
  task = EmailTask.new(imap_setting)
  TaskExecutor.schedule_periodic(schedule, task)
  
