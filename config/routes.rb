require 'events'

Eventsource::Application.routes.draw do
  root :to => 'home#index'
  mount Events => '/events'
end
