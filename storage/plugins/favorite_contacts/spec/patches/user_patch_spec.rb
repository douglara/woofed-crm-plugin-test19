require "rails_helper"

RSpec.describe "User patch (favorite_contacts plugin)" do
  let(:original) { Rails.root.join("app/models/user.rb").read }

  before { Plugins::FilePatch.clear_registry! }
  after  { Plugins::FilePatch.clear_registry! }

  it "adds the include line for UserExtension" do
    load Rails.root.join("storage/plugins/favorite_contacts/app/models/user.rb")
    result = Plugins::FilePatch.apply("app/models/user.rb", original)

    expect(result).to include("include Plugins::FavoriteContacts::UserExtension")
  end

  it "does not modify the original file" do
    original_content = Rails.root.join("app/models/user.rb").read
    expect(original_content).not_to include("Plugins::FavoriteContacts::UserExtension")
  end
end
