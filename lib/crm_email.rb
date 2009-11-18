# CrmEmail

require 'task_executor'
require 'email_task'
  
  #start task executor daemon
  TaskExecutor.start()

  imap_setting = Setting[:email_imap]
  schedule = imap_setting[:mode] == "prod" ? imap_setting[:schedule] : "1m"
  
  #schedule email task
  task = EmailTask.new(imap_setting)
  TaskExecutor.schedule_periodic(schedule, task)
  
