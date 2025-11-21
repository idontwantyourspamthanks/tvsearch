Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "episodes#index"
  resources :episodes, only: %i[index show]

  get "/admin/login", to: "admin_sessions#new", as: :admin_login
  post "/admin/login", to: "admin_sessions#create"
  delete "/admin/logout", to: "admin_sessions#destroy", as: :admin_logout

  namespace :admin do
    root to: "episodes#index"
    resources :episodes, except: :show
    resources :shows, except: :show
  end
end
