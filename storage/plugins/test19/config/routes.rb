resources :accounts, module: :accounts, only: [] do
  resources :world_clock, only: [:index]
end
