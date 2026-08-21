Rails.application.config.after_initialize do
  # new_resource: false is required — omitting it is a real bug both
  # sibling extensions (spree_square, spree_doordash) hit and fixed on
  # their first real Postgres run: without it, Spree.admin's table
  # renderer assumes a "New" action exists and 500s. Avoided here by
  # copying the already-fixed pattern instead of rediscovering it.
  Spree.admin.tables.register(:uber_direct_delivery_mappings, model_class: SpreeUberDirect::DeliveryMapping,
                                                                search_param: :external_delivery_id_cont, new_resource: false)

  Spree.admin.tables.uber_direct_delivery_mappings.add :order_number,
    label: :order,
    type: :string,
    sortable: false,
    filterable: false,
    default: true,
    position: 10,
    method: ->(mapping) { mapping.order&.number }

  Spree.admin.tables.uber_direct_delivery_mappings.add :external_delivery_id,
    label: :external_delivery_id,
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 20

  Spree.admin.tables.uber_direct_delivery_mappings.add :last_status,
    label: :status,
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 30

  Spree.admin.tables.uber_direct_delivery_mappings.add :tracking_url,
    label: :tracking_url,
    type: :string,
    sortable: false,
    filterable: false,
    default: true,
    position: 40

  Spree.admin.tables.uber_direct_delivery_mappings.add :dispatch_error,
    label: :dispatch_error,
    type: :string,
    sortable: false,
    filterable: false,
    default: true,
    position: 50

  Spree.admin.tables.uber_direct_delivery_mappings.add :created_at,
    label: :created_at,
    type: :datetime,
    sortable: true,
    filterable: false,
    default: true,
    position: 60

  Spree.admin.tables.register(:uber_direct_webhook_events, model_class: SpreeUberDirect::WebhookEvent,
                                                             search_param: :delivery_id_cont, new_resource: false)

  Spree.admin.tables.uber_direct_webhook_events.add :delivery_id,
    label: :delivery_id,
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 10

  Spree.admin.tables.uber_direct_webhook_events.add :status,
    label: :status,
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 20

  Spree.admin.tables.uber_direct_webhook_events.add :processing_status,
    label: :processing_status,
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 30

  Spree.admin.tables.uber_direct_webhook_events.add :error_message,
    label: :error_message,
    type: :string,
    sortable: false,
    filterable: false,
    default: true,
    position: 40

  Spree.admin.tables.uber_direct_webhook_events.add :created_at,
    label: :created_at,
    type: :datetime,
    sortable: true,
    filterable: false,
    default: true,
    position: 50
end
