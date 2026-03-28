require "rails_helper"

RSpec.describe "ai_features deals_controller.rb patch" do
  let(:original) { Rails.root.join("app/controllers/accounts/deals_controller.rb").read }

  before { Plugins::FilePatch.clear_registry! }
  after  { Plugins::FilePatch.clear_registry! }

  before do
    load Rails.root.join("storage/plugins/ai_features/app/controllers/accounts/deals_controller.rb")
  end

  it "adds toggle_ai_followup to the before_action list" do
    result = Plugins::FilePatch.apply("app/controllers/accounts/deals_controller.rb", original)
    expect(result).to include("toggle_ai_followup")
  end

  it "adds the toggle_ai_followup action" do
    result = Plugins::FilePatch.apply("app/controllers/accounts/deals_controller.rb", original)
    expect(result).to include("def toggle_ai_followup")
  end

  it "adds create_ai_followup_events private method" do
    result = Plugins::FilePatch.apply("app/controllers/accounts/deals_controller.rb", original)
    expect(result).to include("def create_ai_followup_events")
  end

  it "adds delete_ai_followup_events private method" do
    result = Plugins::FilePatch.apply("app/controllers/accounts/deals_controller.rb", original)
    expect(result).to include("def delete_ai_followup_events")
  end

  it "does not modify the original file on disk" do
    expect(original).not_to include("toggle_ai_followup")
  end
end
