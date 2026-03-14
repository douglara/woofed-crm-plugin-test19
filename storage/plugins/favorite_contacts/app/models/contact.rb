Plugins::FilePatch.define target: "app/models/contact.rb" do
  after_line containing: "class Contact < ApplicationRecord" do
    "  include Plugins::FavoriteContacts::ContactExtension"
  end
end
