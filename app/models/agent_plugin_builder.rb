# == Schema Information
#
# Table name: agent_plugin_builders
#
#  id            :bigint           not null, primary key
#  branch_name   :string
#  description   :text
#  error_message :text
#  logs          :text
#  name          :string           default(""), not null
#  repo_url      :string
#  status        :string           default("pending"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_agent_plugin_builders_on_account_id  (account_id)
#  index_agent_plugin_builders_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class AgentPluginBuilder < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :name, presence: true
  validates :description, presence: true

  enum status: {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name description status created_at updated_at]
  end

  def append_log(message)
    current = logs || ''
    update(logs: current + "[#{Time.current.iso8601}] #{message}\n")
  end
end
