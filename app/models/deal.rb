Plugins::FilePatch.define target: "app/models/deal.rb" do
  after_line containing: "include Deal::HandleInCentsValues" do
    "  include Plugins::AiFeatures::DealExtension"
  end
end
