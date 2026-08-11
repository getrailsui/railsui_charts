RailsuiCharts::Engine.routes.draw do
  get "/demo", to: "demo#index"
  root to: "demo#index"
end
