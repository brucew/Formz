class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :forms, foreign_key: :owner_id, inverse_of: :owner, dependent: :destroy
  has_many :submissions, dependent: :destroy

  def submitted?(form)
    submissions.exists?(form: form)
  end
end
