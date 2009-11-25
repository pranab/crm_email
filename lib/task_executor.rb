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

require 'openwfe/util/scheduler'
include OpenWFE

class TaskExecutor
  def initialize
    
  end

  # Schedule periodic task
  def self.schedule_periodic(interval, task, param = {})
    job_id = @@scheduler.schedule_every(interval, param) { task.execute }
    task.job_id = job_id
  end

  # Schedule one time future task
  def self.schedule_future(duration, task, param = {})
    job _id = @@scheduler.schedule_in(duration, param) { task.execute }
    task.job_id = job_id
  end

  def self.unschedule(task)
    @@scheduler.unschedule(task.job_id)
  end
  
  # Setup scheduler
  def self.start
    @@scheduler = Scheduler.new
    @@scheduler.start
  end

  def self.stop
    @@scheduler.stop
  end
  
end
