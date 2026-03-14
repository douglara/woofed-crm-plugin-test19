require "rails_helper"

RSpec.describe "Contact patch (favorite_contacts plugin)" do
  let(:original) { Rails.root.join("app/models/contact.rb").read }

  before { Plugins::FilePatch.clear_registry! }
  after  { Plugins::FilePatch.clear_registry! }

  it "adds the include line for ContactExtension" do
    load Rails.root.join("plugins/favorite_contacts/app/models/contact.rb")
    result = Plugins::FilePatch.apply("app/models/contact.rb", original)

    expect(result).to include("include Plugins::FavoriteContacts::ContactExtension")
  end

  it "does not modify the original file" do
    original_content = Rails.root.join("app/models/contact.rb").read
    expect(original_content).not_to include("Plugins::FavoriteContacts::ContactExtension")
  end
end
