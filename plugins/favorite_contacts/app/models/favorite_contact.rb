class FavoriteContact < ApplicationRecord
  belongs_to :user
  belongs_to :contact

  validates :contact_id, uniqueness: { scope: :user_id, message: :already_favorited }
end
