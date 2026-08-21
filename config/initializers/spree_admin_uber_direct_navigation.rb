Rails.application.config.after_initialize do
  # Position 76 — confirmed the next free slot at time of writing (highest
  # in use across every extension's own nav initializer was 75, spree_loyalty's
  # admin_square_modifier_lists_navigation.rb before that at 73). 77-78 are
  # the M5 Deliveries/Webhooks admin index pages below, mirroring
  # spree_doordash's 68-70 layout (credential + 2 read-only tables).
  Spree.admin.navigation.sidebar.add :uber_direct_credential,
    label: 'Uber Direct Connection',
    url: :admin_uber_direct_credential_path,
    icon: 'plug',
    position: 76,
    active: -> { controller_name == 'uber_direct_credentials' },
    if: -> { can?(:manage, SpreeUberDirect::Credential) }

  Spree.admin.navigation.sidebar.add :uber_direct_delivery_mappings,
    label: 'Uber Direct Deliveries',
    url: :admin_uber_direct_delivery_mappings_path,
    icon: 'truck',
    position: 77,
    active: -> { controller_name == 'uber_direct_delivery_mappings' },
    if: -> { can?(:manage, SpreeUberDirect::DeliveryMapping) }

  Spree.admin.navigation.sidebar.add :uber_direct_webhook_events,
    label: 'Uber Direct Webhooks',
    url: :admin_uber_direct_webhook_events_path,
    icon: 'webhook',
    position: 78,
    active: -> { controller_name == 'uber_direct_webhook_events' },
    if: -> { can?(:manage, SpreeUberDirect::WebhookEvent) }
end
