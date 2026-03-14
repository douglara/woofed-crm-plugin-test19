require 'rails_helper'

RSpec.describe 'Agent Plugin Builders API', type: :request do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let(:auth_headers) { { 'Authorization': "Bearer #{user.get_jwt_token}", 'Content-Type': 'application/json' } }

  describe 'POST /api/v1/accounts/{account.id}/agent_plugin_builders' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/agent_plugin_builders",
             params: { description: 'Add a new button' }.to_json,
             headers: { 'Content-Type': 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'creates an agent plugin builder' do
        expect do
          post "/api/v1/accounts/#{account.id}/agent_plugin_builders",
               params: { description: 'Mudar a cor de fundo do header para verde' }.to_json,
               headers: auth_headers
        end.to change(AgentPluginBuilder, :count).by(1)

        expect(response).to have_http_status(:created)
        result = JSON.parse(response.body)
        expect(result['description']).to eq('Mudar a cor de fundo do header para verde')
        expect(result['status']).to eq('pending')
      end

      it 'returns error when description is blank' do
        post "/api/v1/accounts/#{account.id}/agent_plugin_builders",
             params: { description: '' }.to_json,
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/agent_plugin_builders' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/agent_plugin_builders"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let!(:agent_plugin_builder) do
        create(:agent_plugin_builder, account: account, user: user,
               description: 'Test feature')
      end

      it 'returns list of agent plugin builders' do
        get "/api/v1/accounts/#{account.id}/agent_plugin_builders", headers: auth_headers

        expect(response).to have_http_status(:ok)
        result = JSON.parse(response.body)
        expect(result.length).to eq(1)
        expect(result.first['description']).to eq('Test feature')
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/agent_plugin_builders/{id}' do
    context 'when it is an unauthenticated user' do
      let!(:agent_plugin_builder) { create(:agent_plugin_builder, account: account, user: user) }

      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/agent_plugin_builders/#{agent_plugin_builder.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let!(:agent_plugin_builder) do
        create(:agent_plugin_builder, :completed, account: account, user: user)
      end

      it 'returns the agent plugin builder details' do
        get "/api/v1/accounts/#{account.id}/agent_plugin_builders/#{agent_plugin_builder.id}",
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        result = JSON.parse(response.body)
        expect(result['status']).to eq('completed')
        expect(result['repo_url']).to be_present
        expect(result['branch_name']).to be_present
      end
    end
  end
end
