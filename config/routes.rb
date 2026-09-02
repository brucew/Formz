Rails.application.routes.draw do
  devise_for :users

  resources :forms, only: %i[index show] do
    resource :submission, only: %i[new create show]
  end

  namespace :admin do
    resources :forms do
      resources :submissions, only: :index
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Admins land on the forms they own; everyone else lands on the forms they can fill out.
  authenticated :user, ->(user) { user.admin? } do
    root "admin/forms#index", as: :admin_root
  end

  root "forms#index"
end
