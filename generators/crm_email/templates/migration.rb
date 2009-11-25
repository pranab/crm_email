class CreateEmails < ActiveRecord::Migration
  def self.up
    create_table :emails, :force => true do |table|
      table.string   :msgid, :null => false          
      table.string   :from, :null => false          
      table.string   :to, :null => false          
      table.string   :cc                             
      table.string   :bcc          
      table.string   :subject          
      table.text     :body
      table.string   :ref_msgid          
      table.datetime :received_at    
      table.references  :user, :null => false      
      table.references  :comment     
      table.timestamps
    end
    
    create_table :contacts_emails, :id => false, :force => true do |table|
      table.references  :contact, :null => false     
      table.references  :email, :null => false     
      table.timestamps
    end

  end
  
  def self.down
    drop_table :contacts_emails  
    drop_table :emails  
  end
end