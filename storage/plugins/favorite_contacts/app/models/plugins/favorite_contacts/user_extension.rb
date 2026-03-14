module Plugins
  module FavoriteContacts
    module UserExtension
      extend ActiveSupport::Concern

      included do
        has_many :favorite_contacts, dependent: :destroy
        has_many :favorited_contacts, through: :favorite_contacts, source: :contact
      end
    end
  end
end
