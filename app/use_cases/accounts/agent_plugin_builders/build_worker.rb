class Accounts::AgentPluginBuilders::BuildWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 1

  def perform(agent_plugin_builder_id)
    agent_plugin_builder = AgentPluginBuilder.find(agent_plugin_builder_id)
    Accounts::AgentPluginBuilders::Build.call(agent_plugin_builder)
  end
end
