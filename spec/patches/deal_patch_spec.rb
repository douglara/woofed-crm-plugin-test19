require "rails_helper"

RSpec.describe "ai_features deal.rb patch" do
  let(:original) { Rails.root.join("app/models/deal.rb").read }

  before { Plugins::FilePatch.clear_registry! }
  after  { Plugins::FilePatch.clear_registry! }

  it "inserts include after HandleInCentsValues" do
    load Rails.root.join("storage/plugins/ai_features/app/models/deal.rb")
    result = Plugins::FilePatch.apply("app/models/deal.rb", original)
    expect(result).to include("include Plugins::AiFeatures::DealExtension")
  end

  it "places the include immediately after HandleInCentsValues" do
    load Rails.root.join("storage/plugins/ai_features/app/models/deal.rb")
    result = Plugins::FilePatch.apply("app/models/deal.rb", original)
    lines = result.lines.map(&:chomp)
    handle_idx    = lines.index { |l| l.include?("include Deal::HandleInCentsValues") }
    extension_idx = lines.index { |l| l.include?("include Plugins::AiFeatures::DealExtension") }
    expect(extension_idx).to eq(handle_idx + 1)
  end

  it "does not modify the original file on disk" do
    expect(original).not_to include("AiFeatures")
  end
end
