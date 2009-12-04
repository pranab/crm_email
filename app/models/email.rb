class Email < ActiveRecord::Base
  belongs_to  :user
  has_and_belongs_to_many  :contacts
  belongs_to  :comment
end
