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
FactoryBot.define do
  factory :agent_plugin_builder do
    account
    user
    description { 'Mudar a cor de fundo do header para verde' }

    trait :processing do
      status { 'processing' }
    end

    trait :completed do
      status { 'completed' }
      repo_url { 'https://github.com/testuser/woofed-crm-ai-abc123.git' }
      branch_name { 'ai-feature/mudar-a-cor-de-fundo-abc12345' }
    end

    trait :failed do
      status { 'failed' }
      error_message { 'OpenCode did not produce any changes' }
    end
  end
end
