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

require 'net/imap'
require 'tmail'
require 'base_task'

class EmailTask < BaseTask
  
  def initialize (imap_setting)
    #get IMAP settings
    ActiveRecord::Base.establish_connection(Rails.env)
    @imap_setting = imap_setting
  end

  #process all emails in dropbox
  def execute
    @imap = Net::IMAP.new(@imap_setting[:server], @imap_setting[:port].to_i)
    @imap.login(@imap_setting[:user], @imap_setting[:password])
    @imap.select(@imap_setting[:folder])
    
    #process all mail read email with test in subject for testing purpose. In reality it will process all emails
    query = imap_setting[:mode] == "prod" ? ['NOT', 'SEEN'] : ['SUBJECT', 'test']
    @imap.uid_search(query).each do |uid|
      catch(:continue) do
        mail = TMail::Mail.parse( imap.uid_fetch(uid, 'RFC822').first.attr['RFC822'] )
        from = mail.from
        to = mail.to
        bcc = mail.bcc
        cc = mail.cc
        subject = mail.subject
        msgid = mail.message_id 
        date = mail.date
        ref_msgid = [mail.in_reply_to, mail.references].flatten.compact.join(" ")          
        
        #normalize all email addresses
        from.map! {|address| normalize_address(address) }
        to.map! {|address| normalize_address(address) }
        cc.map! {|address| normalize_address(address) } unless cc.is_nil?
        bcc.map! {|address| normalize_address(address) } unless bcc.is_nil?

        #find matching user
        user = nil
        user_email = from.find do |f|
          user = User.find_by_email(f.downcase)
        end
        
        if user
          logger.info "processing email for #{user.username}"
          if bcc.include?(@imap_setting[:email])
            #if from as user or asignee to as contact and we are in bcc it's outbound
            contacts = to.map do |t|
              #find contact by user or assigned to
              contact = Contact.find_by_email_and_user(t, user)
              if contact.nil?
                contact = Contact.find_by_email_and_assignee(t, user)
              end
              
              if contact.nil?
                #create contact, user is emailing a contact that's not in FFC
                logger.info "new contact #{t}"
                contact = Contact.new
                contact.user = user
                contact.email = t
                unless contact.save 
                  logger.warn "could not save contact #{t}"
                  contact = nil
                end
              end
              contact
            end
            contacts.compact!
            
            #save mail
            from_list = from.join(" ")
            to_list = to.join(" ")
            cc_list = cc.join(" ")
            bcc_list = bcc.join(" ")
            body = mail.quoted_body
            save_email(from_list, to_list, subject, cc_list, bcc_list, body, msgid, ref_msgid, date, user, contacts)
          else
            #TODO if fowarded msg has from as user and to as contact it's inbound
          
          end
          
        else
          #unknown sender,this email is not supposed to be in drop box
          logger.warn "mail from unknown user from: #{from}  to: #{to} subject: #{subject}"
          handle_processed_mail(uid) if @imap_setting[:mode] == "prod"
        end
        
      end
      
    end
    @imap.logout
    @imap.disconnect
     
    rescue Net::IMAP::NoResponseError => e
      logger.error "IMAP server error"
    rescue Net::IMAP::ByeResponseError => e
      logger.error "IMAP server error"
    rescue => e
      logger.error "IMAP server error"
 
  end
  
  
  private
  #since the domain is case insensitive, always downcase the domain part
  def nomalize_address(address)
    address.gsub(/@\w+\.\w+/) { |s| s.downcase}
  end

  #save email
  def save_email (from_list, to_list, subject, cc_list, bcc_list, body, msgid, ref_msgid, date, user, contacts)
    email = Email.new
    email.from = from_list
    email.to = to_list
    email.subject = subject
    email.cc = cc_list
    email.bcc = bcc_list
    email.body = body
    email.msgid = msgid
    email.ref_msgid = ref_msgid      
    email.received_at = date
    email.user = user
    email.contacts = contacts
    if (email.save)
      logger.info "email saved"
      #save attachment
      #save_attachment(mail)
      
      #move or delete processed mail
      handle_processed_mail(uid) if @imap_setting[:mode] == "prod"
    else
      logger.warn "failed to save email from: #{from}  to: #{to} subject: #{subject}"
    end
  
  end
  
  #save attachment
  def save_attachment(mail)
    if !mail.attachments.blank?
      File.open(mail.attachments.first.original_filename,"w+") do |local_file|
        local_file << mail.attachments.first.gets(nil)
      end
    end
  end
  
  #after prcessing move email to folder if configured, delete otherwise
  def handle_processed_mail(uid)
    @imap.uid_copy(uid, @imap_setting[:move_folder]) if (@imap_setting[:move_folder])
    @imap.uid_store(uid, "+FLAGS", [:Deleted])
  end
  
  def logger
    RAILS_DEFAULT_LOGGER
  end
  
  
end
