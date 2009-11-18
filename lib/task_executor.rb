# To change this template, choose Tools | Templates
# and open the template in the editor.

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
