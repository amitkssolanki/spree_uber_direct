Spree::Core::Engine.add_routes do
  # Same absolute-path pattern as spree_doordash's own webhook route —
  # isolate_namespace Spree means a plain `namespace :spree_uber_direct`
  # would resolve to Spree::SpreeUberDirect::..., not the real
  # SpreeUberDirect::WebhooksController; the leading `/` makes the
  # controller path absolute while keeping the URL prefix.
  post 'spree_uber_direct/webhooks/uber_direct', to: '/spree_uber_direct/webhooks#create'

  namespace :admin do
    # Plain credential-entry form (client_id/client_secret/customer_id/
    # webhook signing key) — same explicit named-route shape as
    # spree_doordash's own doordash_credential, not `resource :...` since
    # there's no `new`/`create`, just `find_or_initialize_by(store:)`.
    get 'uber_direct_credential' => 'uber_direct_credentials#show', as: :uber_direct_credential
    patch 'uber_direct_credential' => 'uber_direct_credentials#update'

    # M5 — admin support/diagnostic pages, same read-only shape as every
    # sibling extension's own (:index only).
    resources :uber_direct_delivery_mappings, only: [:index]
    resources :uber_direct_webhook_events, only: [:index]
  end
end
