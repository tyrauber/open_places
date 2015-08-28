OpenPlaces::Engine.routes.draw do
  resources :autocomplete, only: [:index], :defaults => { format: 'json' }
  # resources :countries, controller: :api, type: "OpenPlaces::Country" do
  #   resources :provinces, controller: :api, type: "OpenPlaces::Province" do
  #     resources :place, controller: :api, type: "OpenPlaces::Place" do
  #     end
  #   end
  # end
  # resources :provinces, controller: :api, type: "OpenPlaces::Province"
  # resources :place, controller: :api, type: "OpenPlaces::Place"
  resources :demo, only: "index"
  root to: "autocomplete#index"
end
