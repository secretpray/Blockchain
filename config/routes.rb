Rails.application.routes.draw do
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "root#index"

  get "up" => "rails/health#show", as: :rails_health_check

  resource  :session, only: %i[create destroy]
  resource  :wallet, only: :show, controller: "wallet"


  namespace :api do
    namespace :v1 do
      get "users/index"
      get "users/show"
      resources :users, only: %i[index show], param: :eth_address
    end
  end
end
