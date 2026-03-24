Rubot::Engine.routes.draw do
  resources :runs, only: %i[index show] do
    resources :tool_calls, only: [:show], controller: "tool_calls"
  end
  resources :approvals, only: [:index], controller: "approvals" do
    patch :approve, on: :member
    patch :reject, on: :member
  end

  root to: "runs#index"
end
