require "rails_helper"

RSpec.describe Accounts::AiFollowupsController, type: :request do
  let(:user)    { create(:user) }
  let(:account) { user.account }

  before { sign_in user }

  describe "GET /accounts/:account_id/ai_followups" do
    it "returns http success" do
      get account_ai_followups_path(account)
      expect(response).to have_http_status(:success)
    end

    context "with ai-generated events" do
      let(:contact) { create(:contact, account: account) }
      let(:deal)    { create(:deal, contact: contact) }
      let!(:pending_event) do
        create(:event, contact: contact, deal: deal,
               scheduled_at: 3.days.from_now, done_at: nil,
               additional_attributes: { 'ai_generated' => true })
      end
      let!(:done_event) do
        create(:event, contact: contact, deal: deal,
               scheduled_at: 7.days.ago, done_at: 1.day.ago,
               additional_attributes: { 'ai_generated' => true })
      end

      it "assigns pending and done counts" do
        get account_ai_followups_path(account)
        expect(assigns(:total_pending)).to eq(1)
        expect(assigns(:total_done)).to eq(1)
      end
    end
  end
end
