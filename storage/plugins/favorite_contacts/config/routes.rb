resources :accounts, module: :accounts, only: [] do
  resources :favorite_contacts, only: [:index] do
    collection do
      post ':contact_id/favorite', action: :create, as: :create
      delete ':contact_id/unfavorite', action: :destroy, as: :destroy
    end
  end
end
