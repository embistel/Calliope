Rails.application.routes.draw do
  root "projects#index"
  resources :projects, only: [:index, :show, :create, :update, :destroy] do
    member do
      post :generate_video
      post :cancel_video
    end
    resources :dubbing_items, only: [:create, :update, :destroy] do
      member do
        post :upload_image
        post :generate_dubbing
      end
    end
  end
end
