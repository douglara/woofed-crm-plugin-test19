require 'rails_helper'

RSpec.describe Accounts::AgentPluginBuilders::Create do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe '.call' do
    it 'creates an agent plugin builder with pending status' do
      result = described_class.call(account, user, 'Add a new dashboard widget')

      expect(result[:ok]).to be_a(AgentPluginBuilder)
      expect(result[:ok].status).to eq('pending')
      expect(result[:ok].description).to eq('Add a new dashboard widget')
      expect(result[:ok].account).to eq(account)
      expect(result[:ok].user).to eq(user)
    end

    it 'enqueues a build worker' do
      expect(Accounts::AgentPluginBuilders::BuildWorker).to receive(:perform_async).with(an_instance_of(Integer))

      described_class.call(account, user, 'Add a new feature')
    end

    it 'returns error when description is blank' do
      result = described_class.call(account, user, '')

      expect(result[:error]).to be_a(AgentPluginBuilder)
      expect(result[:error].errors[:description]).to be_present
    end
  end
end
