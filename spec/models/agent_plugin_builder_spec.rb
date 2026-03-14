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
require 'rails_helper'

RSpec.describe AgentPluginBuilder, type: :model do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      feature_request = build(:agent_plugin_builder, account: account, user: user)
      expect(feature_request).to be_valid
    end

    it 'is not valid without a description' do
      feature_request = build(:agent_plugin_builder, account: account, user: user, description: nil)
      expect(feature_request).not_to be_valid
    end
  end

  describe 'default status' do
    it 'defaults to pending' do
      feature_request = create(:agent_plugin_builder, account: account, user: user)
      expect(feature_request.status).to eq('pending')
    end
  end

  describe '#append_log' do
    it 'appends a log message with timestamp' do
      feature_request = create(:agent_plugin_builder, account: account, user: user)
      feature_request.append_log('Test message')
      expect(feature_request.reload.logs).to include('Test message')
    end

    it 'appends multiple log messages' do
      feature_request = create(:agent_plugin_builder, account: account, user: user)
      feature_request.append_log('First message')
      feature_request.append_log('Second message')
      expect(feature_request.reload.logs).to include('First message')
      expect(feature_request.reload.logs).to include('Second message')
    end
  end

  describe 'status enum' do
    it 'supports pending status' do
      feature_request = create(:agent_plugin_builder, account: account, user: user, status: :pending)
      expect(feature_request).to be_pending
    end

    it 'supports processing status' do
      feature_request = create(:agent_plugin_builder, account: account, user: user, status: :processing)
      expect(feature_request).to be_processing
    end

    it 'supports completed status' do
      feature_request = create(:agent_plugin_builder, account: account, user: user, status: :completed)
      expect(feature_request).to be_completed
    end

    it 'supports failed status' do
      feature_request = create(:agent_plugin_builder, account: account, user: user, status: :failed)
      expect(feature_request).to be_failed
    end
  end
end
