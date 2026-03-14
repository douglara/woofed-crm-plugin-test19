require "rails_helper"

RSpec.describe Plugins::FavoriteContacts::ContactExtension, type: :model do
  let!(:account) { create(:account) }
  let(:user) { create(:user) }
  let(:contact) { create(:contact) }

  describe "#favorited_by?" do
    it "returns true when the contact is favorited by the user" do
      FavoriteContact.create!(user: user, contact: contact)

      expect(contact.favorited_by?(user)).to be true
    end

    it "returns false when the contact is not favorited by the user" do
      expect(contact.favorited_by?(user)).to be false
    end
  end

  describe "associations" do
    it "has many favorite_contacts" do
      favorite = FavoriteContact.create!(user: user, contact: contact)

      expect(contact.favorite_contacts).to include(favorite)
    end

    it "has many favorited_by_users through favorite_contacts" do
      FavoriteContact.create!(user: user, contact: contact)

      expect(contact.favorited_by_users).to include(user)
    end

    it "destroys favorite_contacts when contact is destroyed" do
      FavoriteContact.create!(user: user, contact: contact)

      expect { contact.destroy }.to change(FavoriteContact, :count).by(-1)
    end
  end
end
