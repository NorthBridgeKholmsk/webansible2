Rails.application.routes.draw do
  root "dashboard#index"

  resources :sessions, only: [:new, :create, :destroy]
  delete "logout", to: "sessions#destroy"

  resources :organizations, only: [:index, :show, :new, :create, :edit, :update, :destroy]
  resources :hosts, only: [:index, :show, :new, :create, :edit, :update, :destroy]

  resources :playbooks, only: [:index, :show, :new, :create, :edit, :update, :destroy]
  resources :files, only: [:index, :show, :new, :create, :edit, :update, :destroy]

  resources :users, only: [:index, :new, :create, :edit, :update, :destroy]

  get "run", to: "runs#new", as: :new_run
   post "run", to: "runs#create", as: :run

  get "settings", to: "settings/application#show"
  patch "settings", to: "settings/application#update"

  get "settings/options/new/:category", to: "settings/application#edit_option", as: :edit_option, constraints: { category: %r{type|role|os_type} }
  patch "settings/options/:category", to: "settings/application#update_option", as: :update_option, constraints: { category: %r{type|role|os_type} }
end
