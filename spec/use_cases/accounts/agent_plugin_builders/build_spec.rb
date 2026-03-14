require 'rails_helper'

RSpec.describe Accounts::AgentPluginBuilders::Build do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:agent_plugin_builder) { create(:agent_plugin_builder, account: account, user: user) }

  describe '.call' do
    context 'when GITHUB_TOKEN is not set' do
      before { allow(ENV).to receive(:fetch).with('GITHUB_TOKEN', nil).and_return(nil) }

      it 'fails with missing token error' do
        result = described_class.call(agent_plugin_builder)

        expect(result[:error]).to include('GITHUB_TOKEN')
        expect(agent_plugin_builder.reload.status).to eq('failed')
      end
    end

    context 'when GITHUB_TOKEN is set' do
      let(:fork_response_body) do
        { 'clone_url' => 'https://github.com/testuser/woofed-crm-ai-abc123.git',
          'full_name' => 'testuser/woofed-crm-ai-abc123' }.to_json
      end

      let(:fork_ready_body) { { 'id' => 1 }.to_json }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('GITHUB_TOKEN', nil).and_return('fake-token')

        # Stub the fork API
        stub_request(:post, 'https://api.github.com/repos/douglara/woofed-crm/forks')
          .to_return(status: 202, body: fork_response_body, headers: { 'Content-Type' => 'application/json' })

        # Stub the fork readiness check
        stub_request(:get, 'https://api.github.com/repos/testuser/woofed-crm-ai-abc123')
          .to_return(status: 200, body: fork_ready_body, headers: { 'Content-Type' => 'application/json' })

        # Stub git and opencode commands
        allow_any_instance_of(described_class).to receive(:run_command).and_return('')
        allow_any_instance_of(described_class).to receive(:run_git_command).and_return('')
        allow_any_instance_of(described_class).to receive(:run_streaming_command).and_return('opencode output')

        # Make status --porcelain return something
        allow_any_instance_of(described_class).to receive(:run_git_command)
          .with("status --porcelain").and_return("M file.rb\n")

        # Stub cleanup
        allow(FileUtils).to receive(:rm_rf)
        allow(FileUtils).to receive(:mkdir_p)
      end

      it 'updates agent plugin builder to processing then completed' do
        result = described_class.call(agent_plugin_builder)

        expect(agent_plugin_builder.reload.status).to eq('completed')
        expect(agent_plugin_builder.repo_url).to be_present
        expect(agent_plugin_builder.branch_name).to be_present
      end
    end
  end
end
