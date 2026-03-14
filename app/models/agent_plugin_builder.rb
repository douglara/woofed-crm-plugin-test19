# == Schema Information
#
# Table name: agent_plugin_builders
#
#  id            :bigint           not null, primary key
#  account_id    :bigint           not null
#  user_id       :bigint           not null
#  description   :text             not null
#  status        :string           default("pending"), not null
#  repo_url      :string
#  branch_name   :string
#  logs          :text
#  error_message :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
class AgentPluginBuilder < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :description, presence: true

  enum status: {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }

  def append_log(message)
    current = logs || ''
    update(logs: current + "[#{Time.current.iso8601}] #{message}\n")
  end
end
