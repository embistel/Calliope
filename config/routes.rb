Rails.application.routes.draw do
  root "projects#index"
  resources :projects, only: [:index, :show, :create, :update, :destroy] do
    resources :dubbing_items, only: [:create, :update, :destroy] do
      member do
        post :upload_image
      end
    end
  end
end
