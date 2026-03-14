Plugins::FilePatch.define target: "app/models/user.rb" do
  after_line containing: "class User < ApplicationRecord" do
    "  include Plugins::FavoriteContacts::UserExtension"
  end
end
