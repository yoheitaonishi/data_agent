require 'sidekiq/web'
Rails.application.routes.draw do
  mount Sidekiq::Web => "/sidekiq"
  resources :agentic_jobs, only: [ :show ]
  post "agentic_jobs/execute", to: "agentic_jobs#execute", as: :execute_agentic_job
  get "top/dev"
  get "top/contract_data"
  get "top/saved_contract_data", as: :saved_contract_data
  post "top/obic7_import_demo", to: "top#obic7_import_demo", as: :obic7_import_demo
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "top#index"
end
