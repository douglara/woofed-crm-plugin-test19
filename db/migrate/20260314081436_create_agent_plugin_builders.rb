class CreateAgentPluginBuilders < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_plugin_builders do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :description, null: false
      t.string :status, null: false, default: 'pending'
      t.string :repo_url
      t.string :branch_name
      t.text :logs
      t.text :error_message

      t.timestamps
    end
  end
end
