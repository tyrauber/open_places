Rails.application.routes.draw do
  mount OpenPlaces::Engine, at: "/api"
  root :to => "open_places/demo#index"
end
