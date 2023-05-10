Rails.application.routes.draw do
  root 'home#index'

  post 'api' => 'api#index'
end
