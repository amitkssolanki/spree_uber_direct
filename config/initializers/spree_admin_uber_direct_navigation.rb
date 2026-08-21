Rails.application.config.after_initialize do
  # Position 76 — confirmed the next free slot at time of writing (highest
  # in use across every extension's own nav initializer was 75, spree_loyalty's
  # admin_square_modifier_lists_navigation.rb before that at 73). 77-78
  # reserved for the M5 Deliveries/Webhooks admin index pages, mirroring
  # spree_doordash's 68-70 layout (credential + 2 read-only tables).
  Spree.admin.navigation.sidebar.add :uber_direct_credential,
    label: 'Uber Direct Connection',
    url: :admin_uber_direct_credential_path,
    icon: 'plug',
    position: 76,
    active: -> { controller_name == 'uber_direct_credentials' },
    if: -> { can?(:manage, SpreeUberDirect::Credential) }
end
