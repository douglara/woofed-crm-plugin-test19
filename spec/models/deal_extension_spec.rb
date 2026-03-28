require "rails_helper"

RSpec.describe "Plugins::AiFeatures::DealExtension" do
  let(:deal) { create(:deal) }

  describe "#ai_lead_score" do
    it "returns a value between 0 and 100" do
      expect(deal.ai_lead_score).to be_between(0, 100)
    end

    it "memoizes the result" do
      expect(deal.ai_lead_score).to eq(deal.ai_lead_score)
    end
  end

  describe "#ai_lead_score_label" do
    it "returns :hot when score >= 70" do
      allow(deal).to receive(:ai_lead_score).and_return(75)
      expect(deal.ai_lead_score_label).to eq(:hot)
    end

    it "returns :warm when score is 40-69" do
      allow(deal).to receive(:ai_lead_score).and_return(55)
      expect(deal.ai_lead_score_label).to eq(:warm)
    end

    it "returns :cold when score < 40" do
      allow(deal).to receive(:ai_lead_score).and_return(20)
      expect(deal.ai_lead_score_label).to eq(:cold)
    end
  end

  describe "#ai_lead_score_badge_classes" do
    it "returns green classes for :hot" do
      allow(deal).to receive(:ai_lead_score_label).and_return(:hot)
      expect(deal.ai_lead_score_badge_classes).to include("green")
    end

    it "returns blue classes for :warm" do
      allow(deal).to receive(:ai_lead_score_label).and_return(:warm)
      expect(deal.ai_lead_score_badge_classes).to include("blue")
    end

    it "returns brand classes for :cold" do
      allow(deal).to receive(:ai_lead_score_label).and_return(:cold)
      expect(deal.ai_lead_score_badge_classes).to include("brand-palette")
    end
  end

  describe "#ai_lead_score_label_text" do
    it "returns a translated string" do
      allow(deal).to receive(:ai_lead_score_label).and_return(:hot)
      expect(deal.ai_lead_score_label_text).to be_a(String).and be_present
    end
  end
end
