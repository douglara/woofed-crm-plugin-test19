class Accounts::AgentPluginBuilders::Create
  UPSTREAM_REPO = 'https://github.com/douglara/woofed-crm.git'

  def self.call(account, user, description)
    agent_plugin_builder = AgentPluginBuilder.new(
      account: account,
      user: user,
      description: description,
      status: :pending
    )

    if agent_plugin_builder.save
      Accounts::AgentPluginBuilders::BuildWorker.perform_async(agent_plugin_builder.id)
      { ok: agent_plugin_builder }
    else
      { error: agent_plugin_builder }
    end
  end
end
