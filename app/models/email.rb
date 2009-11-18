class Email < ActiveRecord::Base
  belongs_to  :user
  has_many_and_belongs_to  :contacts
  belongs_to  :comment
end
