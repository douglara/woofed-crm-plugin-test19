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
