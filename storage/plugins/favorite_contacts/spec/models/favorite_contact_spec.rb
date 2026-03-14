require "rails_helper"

RSpec.describe FavoriteContact, type: :model do
  let!(:account) { create(:account) }
  let(:user) { create(:user) }
  let(:contact) { create(:contact) }

  describe "associations" do
    it "belongs to user" do
      favorite = FavoriteContact.new(user: user, contact: contact)
      expect(favorite.user).to eq(user)
    end

    it "belongs to contact" do
      favorite = FavoriteContact.new(user: user, contact: contact)
      expect(favorite.contact).to eq(contact)
    end
  end

  describe "validations" do
    it "validates uniqueness of contact_id scoped to user_id" do
      FavoriteContact.create!(user: user, contact: contact)
      duplicate = FavoriteContact.new(user: user, contact: contact)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:contact_id]).to include(I18n.t('activerecord.errors.models.favorite_contact.attributes.contact_id.already_favorited'))
    end
  end

  describe "uniqueness" do
    it "allows a user to favorite a contact once" do
      FavoriteContact.create!(user: user, contact: contact)
      duplicate = FavoriteContact.new(user: user, contact: contact)

      expect(duplicate).not_to be_valid
    end

    it "allows different users to favorite the same contact" do
      another_user = create(:user)
      FavoriteContact.create!(user: user, contact: contact)
      another_favorite = FavoriteContact.new(user: another_user, contact: contact)

      expect(another_favorite).to be_valid
    end

    it "allows a user to favorite different contacts" do
      another_contact = create(:contact)
      FavoriteContact.create!(user: user, contact: contact)
      another_favorite = FavoriteContact.new(user: user, contact: another_contact)

      expect(another_favorite).to be_valid
    end
  end
end
