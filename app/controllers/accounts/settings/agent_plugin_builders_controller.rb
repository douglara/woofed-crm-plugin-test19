class Accounts::Settings::AgentPluginBuildersController < Inertia::InternalController
  layout 'inertia_overlay'

  before_action :set_agent_plugin_builder, only: %i[show destroy]

  def index
    agent_plugin_builders = Current.account.agent_plugin_builders.order(created_at: :desc)
    render inertia: 'Accounts/Settings/AgentPluginBuilders/Index', props: {
      agent_plugin_builders: agent_plugin_builders.map { |a| serialize(a) }
    }
  end

  def new
    render inertia: 'Accounts/Settings/AgentPluginBuilders/New'
  end

  def create
    result = Accounts::AgentPluginBuilders::Create.call(
      Current.account,
      current_user,
      agent_plugin_builder_params[:name],
      agent_plugin_builder_params[:description]
    )

    if result[:ok]
      redirect_to account_settings_agent_plugin_builder_path(Current.account, result[:ok])
    else
      render inertia: 'Accounts/Settings/AgentPluginBuilders/New', props: {
        errors: result[:error].errors.as_json(full_messages: true),
        values: agent_plugin_builder_params
      }
    end
  end

  def show
    render inertia: 'Accounts/Settings/AgentPluginBuilders/Show', props: {
      agent_plugin_builder: serialize(@agent_plugin_builder)
    }
  end

  def destroy
    @agent_plugin_builder.destroy
    redirect_to account_settings_path(Current.account), status: :see_other
  end

  private

  def set_agent_plugin_builder
    @agent_plugin_builder = Current.account.agent_plugin_builders.find(params[:id])
  end

  def agent_plugin_builder_params
    params.require(:agent_plugin_builder).permit(:name, :description)
  end

  def serialize(agent_plugin_builder)
    {
      id: agent_plugin_builder.id,
      name: agent_plugin_builder.name,
      description: agent_plugin_builder.description,
      status: agent_plugin_builder.status,
      logs: agent_plugin_builder.logs,
      error_message: agent_plugin_builder.error_message,
      repo_url: agent_plugin_builder.repo_url,
      branch_name: agent_plugin_builder.branch_name,
      created_at: agent_plugin_builder.created_at,
      updated_at: agent_plugin_builder.updated_at
    }
  end
end
