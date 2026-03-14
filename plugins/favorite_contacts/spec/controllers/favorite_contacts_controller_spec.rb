require "rails_helper"

RSpec.describe "Accounts::FavoriteContactsController", type: :request do
  let!(:account) { create(:account) }
  let(:user) { create(:user) }
  let(:contact) { create(:contact) }

  before { sign_in user }

  describe "GET /accounts/:account_id/favorite_contacts" do
    it "returns a successful response" do
      get "/accounts/#{account.id}/favorite_contacts"

      expect(response).to have_http_status(:success)
    end

    it "lists the user's favorite contacts" do
      FavoriteContact.create!(user: user, contact: contact)

      get "/accounts/#{account.id}/favorite_contacts"

      expect(response.body).to include(contact.full_name)
    end
  end

  describe "POST /accounts/:account_id/favorite_contacts/:contact_id/favorite" do
    it "creates a favorite contact" do
      expect {
        post "/accounts/#{account.id}/favorite_contacts/#{contact.id}/favorite"
      }.to change(FavoriteContact, :count).by(1)
    end

    it "does not duplicate if already favorited" do
      FavoriteContact.create!(user: user, contact: contact)

      expect {
        post "/accounts/#{account.id}/favorite_contacts/#{contact.id}/favorite"
      }.not_to change(FavoriteContact, :count)
    end

    it "responds with turbo stream" do
      post "/accounts/#{account.id}/favorite_contacts/#{contact.id}/favorite",
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end
  end

  describe "DELETE /accounts/:account_id/favorite_contacts/:contact_id/unfavorite" do
    it "removes the favorite contact" do
      FavoriteContact.create!(user: user, contact: contact)

      expect {
        delete "/accounts/#{account.id}/favorite_contacts/#{contact.id}/unfavorite"
      }.to change(FavoriteContact, :count).by(-1)
    end

    it "handles non-existent favorite gracefully" do
      expect {
        delete "/accounts/#{account.id}/favorite_contacts/#{contact.id}/unfavorite"
      }.not_to change(FavoriteContact, :count)
    end
  end
end
