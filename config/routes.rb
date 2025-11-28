Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "episodes#index"
  resources :episodes, only: %i[index show] do
    post :refresh_image, on: :member
  end

  get "/admin/login", to: "admin_sessions#new", as: :admin_login
  post "/admin/login", to: "admin_sessions#create"
  delete "/admin/logout", to: "admin_sessions#destroy", as: :admin_logout

  namespace :admin do
    root to: "episodes#index"
    resources :episodes, except: :show
    resources :shows, except: :show
    resource :password, only: %i[edit update], controller: "passwords"
    get "tvdb_import", to: "tvdb_imports#new", as: :tvdb_import
    post "tvdb_import", to: "tvdb_imports#create"
    post "tvdb_import/details", to: "tvdb_imports#details", as: :tvdb_import_details
    post "tvdb_import/batch", to: "tvdb_imports#batch", as: :tvdb_import_batch
    get "database/download", to: "database#download", as: :database_download
  end
end
