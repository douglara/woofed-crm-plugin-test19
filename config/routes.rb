resources :accounts, module: :accounts, only: [] do
  resources :deals, only: [] do
    patch 'toggle_ai_followup', on: :member
  end
  resources :ai_followups, only: [:index]
end
