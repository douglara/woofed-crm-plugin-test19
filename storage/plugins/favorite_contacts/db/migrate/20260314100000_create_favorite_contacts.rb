class CreateFavoriteContacts < ActiveRecord::Migration[7.1]
  def change
    create_table :favorite_contacts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true

      t.timestamps
    end

    add_index :favorite_contacts, [:user_id, :contact_id], unique: true
  end
end
