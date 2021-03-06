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
    server = @imap_setting[:server]
    port = @imap_setting[:port].to_i
    ssl = @imap_setting[:ssl]
    @imap = Net::IMAP.new(server, port, ssl)
    @imap.login(@imap_setting[:user], @imap_setting[:password])
    @imap.select(@imap_setting[:folder])
    
    #process all mail read email with test in subject for testing purpose. In reality it will process all emails
    query = @imap_setting[:mode] == "prod" ? ['NOT', 'DELETED'] : ['SUBJECT', 'testin']
    uids = @imap.uid_search(query)
    uids.each do |uid|
      catch(:continue) do
        mail = TMail::Mail.parse( @imap.uid_fetch(uid, 'RFC822').first.attr['RFC822'] )
        from = mail.from
        to = mail.to
        bcc = mail.bcc
        cc = mail.cc
        subject = mail.subject
        msgid = mail.message_id 
        date = mail.date
        ref_msgid = [mail.in_reply_to, mail.references].flatten.compact.uniq.join(" ")
        
        #normalize all email addresses
        from.map! {|address| normalize_address(address) }
        to.map! {|address| normalize_address(address) }
        cc.map! {|address| normalize_address(address) } if cc
        bcc.map! {|address| normalize_address(address) } if bcc

        #find matching user
        user = nil
        user_email = from.find do |f|
          user = User.find_by_email(f.downcase)
        end
        
        if user
          logger.info "processing email for #{user.username}"
          if to.include?(@imap_setting[:user])
            #inbound - forwarded mail from contact
            body = mail.multipart? ? mail.parts[0].body : mail.body
            results = parse_fwd_mail(body)
            
            from = results[0]
            contacts = find_contact(from, user)
            to = results[1]
            cc = results[2]
            cc = nil if cc.empty?
            
            from_list = from.join(" ")
            to_list = to.join(" ")
            cc_list = cc.join(" ") if cc
            bcc_list = nil

            subject = results[3]
            date = results[4]
            ref_msgid = nil


            save_email(from_list, to_list, subject, cc_list, bcc_list, body,
              msgid, ref_msgid, date, user, contacts, uid)
            
          else
            #outbound - bcc mail to contact
            contacts = to.map do |t|
              #find contact by email
              contact = Contact.find_by_email(t)
              
              if contact.nil?
                #create contact, user is emailing a contact that's not in FFC
                logger.info "new contact #{t}"

                if (@imap_setting[:create_contact])
                  contact = Contact.new
                  contact.user = user
                  contact.email = t
                  unless contact.save
                    logger.warn "could not save contact #{t}"
                  end
                end
              end
              contact
            end

            contacts.compact!
            
            #save mail
            from_list = from.join(" ")
            to_list = to.join(" ")
            cc_list = cc ? cc.join(" ") : ''
            bcc_list = bcc ? bcc.join(" ") : ''
            body = mail.multipart? ? mail.parts[0].body : mail.body
            save_email(from_list, to_list, subject, cc_list, bcc_list, body, 
              msgid, ref_msgid, date, user, contacts, uid)
          end
        else
          #unknown sender,this email is not supposed to be in drop box
          logger.warn "mail from unknown user from: #{from}  to: #{to} subject: #{subject}"
          handle_processed_mail(uid) if @imap_setting[:mode] == "prod"
        end
        
      end
      
    end
     
    rescue Net::IMAP::NoResponseError => e
      logger.error "IMAP server error no response" + e
    rescue Net::IMAP::ByeResponseError => e
      logger.error "IMAP server error bye response " + e
    rescue => e
      logger.error "IMAP server error other error" + e
    ensure
      @imap.logout
      @imap.disconnect
 
  end
  
  
  private
  #since the domain is case insensitive, always downcase the domain part
  def normalize_address(address)
    address.gsub(/@\w+\.\w+/) { |s| s.downcase}
  end

  #save email
  def save_email (from_list, to_list, subject, cc_list, bcc_list, body, msgid, 
    ref_msgid, date, user, contacts, uid)
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
      logger.warn "failed to save email from: #{from_list}  to: #{to_list} subject: #{subject}"
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

  #find or create contact from email address
  def find_contact(addrs, user)
    contacts = addrs.map do |addr|
      #find contact email
      contact = Contact.find_by_email(addr)

      if contact.nil?
        #create contact, user is emailing a contact that's not in FFC
        logger.info "new contact #{t}"
        if (@imap_setting[:create_contact])
          contact = Contact.new
          contact.user = user
          contact.email = addr
          unless contact.save
            logger.warn "could not save contact #{addr}"
            contact = nil
          end
        end
      end
      contact
    end

    contacts.compact!
    contacts
  end

  # parses  mail embedded in forwarded mail to extract from and to 
  def parse_fwd_mail(body)
    results = []
    
    from = extract_address(body, 'From:', "Failed to parse from address in forwarded mail body", true)
    to = extract_address(body, 'To:', "Failed to parse to address in forwarded mail body", true)
    cc = extract_address(body, 'CC:', "Failed to parse CC address in forwarded mail body", false)
    results << from  
    results << to  
    results << cc  
    
    subject = extract_text(body, 'Subject:', "Failed to parse subject in forwarded mail body")
    date = extract_text(body, 'Date:', "Failed to parse date in forwarded mail body")
    results << subject
    results << date
    
    results
  end
  
  #extracts address from embedded forwarded email
  def extract_address(body, label, err_msg, mandatory)
    addrs = []
    email_pattern = /[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,4}/
    parts = body.split(label)

    if parts.length == 2
      part = parts[1]
      #part_end = part.index('\n')
      #part = part[0...part_end]
      part.lstrip!
      tokens = part.split(/\s+/)
      part = tokens[0]
      addrs = part.scan(email_pattern)
      raise err_msg if addrs.empty?
    else
      raise err_msg if mandatory
    end
    
    addrs
  end

  
  #extracts other headers from embedded forwarded email
  def extract_text(body, label, err_msg)
    parts = body.split(label)
    raise err_msg if parts.length != 2
    part = parts[1]
    part.lstrip!
    tokens = part.split(/\s+/)
    i = 0
    word_tokens = []
    headers = %{From: To: Subject: Date:}
    while i < tokens.length
      if tokens[i] =~ /\w+/ && !headers.include?(tokens[i])
        word_tokens << tokens[i]
      else
        break
      end
      i += 1
    end
    word_tokens.join(' ')
  end
  
end
