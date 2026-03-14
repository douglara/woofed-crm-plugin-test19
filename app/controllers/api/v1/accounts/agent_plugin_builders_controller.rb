class Api::V1::Accounts::AgentPluginBuildersController < Api::V1::InternalController
  def index
    agent_plugin_builders = AgentPluginBuilder.where(account_id: @current_account.id).order(created_at: :desc)
    render json: agent_plugin_builders, status: :ok
  end

  def show
    agent_plugin_builder = AgentPluginBuilder.find_by!(id: params[:id], account_id: @current_account.id)
    render json: agent_plugin_builder, status: :ok
  end

  def create
    result = Accounts::AgentPluginBuilders::Create.call(
      @current_account,
      @current_user,
      feature_request_params[:description]
    )

    if result[:ok]
      render json: result[:ok], status: :created
    else
      render json: { errors: result[:error].errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def feature_request_params
    params.permit(:description)
  end
end
