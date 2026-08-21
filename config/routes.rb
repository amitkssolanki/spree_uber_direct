Spree::Core::Engine.add_routes do
  namespace :admin do
    # Plain credential-entry form (client_id/client_secret/customer_id/
    # webhook signing key) — same explicit named-route shape as
    # spree_doordash's own doordash_credential, not `resource :...` since
    # there's no `new`/`create`, just `find_or_initialize_by(store:)`.
    get 'uber_direct_credential' => 'uber_direct_credentials#show', as: :uber_direct_credential
    patch 'uber_direct_credential' => 'uber_direct_credentials#update'
  end

  # Webhook route + delivery/webhook-event admin index routes land in M4/M5,
  # once DeliveryMapping/WebhookEvent exist — see spree_doordash's routes.rb
  # for the exact shape to mirror at that point.
end
