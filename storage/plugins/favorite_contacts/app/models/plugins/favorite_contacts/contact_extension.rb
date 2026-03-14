module Plugins
  module FavoriteContacts
    module ContactExtension
      extend ActiveSupport::Concern

      included do
        has_many :favorite_contacts, dependent: :destroy
        has_many :favorited_by_users, through: :favorite_contacts, source: :user
      end

      def favorited_by?(user)
        favorite_contacts.exists?(user: user)
      end
    end
  end
end
