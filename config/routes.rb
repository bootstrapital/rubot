Rubot::Engine.routes.draw do
  root to: "dashboard#index"

  get "dashboard", to: "dashboard#index"
  resources :playground, only: %i[index create], controller: "playground"
  resources :runs, only: %i[index show] do
    post :replay, on: :member
    resources :tool_calls, only: [:show], controller: "tool_calls"
  end
  resources :approvals, only: [:index], controller: "approvals" do
    patch :approve, on: :member
    patch :reject, on: :member
  end

  namespace :api do
    resources :operations, only: %i[index show] do
      post :launch, on: :member
    end
    resources :runs, only: [:show]
    resources :approvals, only: [:index] do
      patch :approve, on: :member
      patch :reject, on: :member
    end
  end
end
