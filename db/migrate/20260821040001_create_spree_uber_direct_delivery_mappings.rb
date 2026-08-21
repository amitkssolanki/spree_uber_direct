class CreateSpreeUberDirectDeliveryMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_uber_direct_delivery_mappings do |t|
      t.references :order, null: false, foreign_key: { to_table: :spree_orders }, index: { unique: true }

      # Uber's own delivery id (prefixed `del_`), returned by
      # POST /deliveries once the quote is accepted — a genuinely separate
      # id from the quote's own `dqt_`-prefixed id, unlike DoorDash (which
      # reuses the accepted quote's external_delivery_id as the delivery's
      # id for its whole lifecycle). Nullable for the same reason
      # SpreeDoordash::DeliveryMapping's own external_delivery_id is: a
      # dispatch can fail before Uber ever returns one (e.g. the
      # underlying quote itself failed) — DeliveryDispatchJob's dead-letter
      # block does find_or_initialize_by(order:).mark_failed!(error) on
      # exactly that path.
      t.string :external_delivery_id

      # Uber's own status vocabulary (pending, pickup, pickup_complete,
      # dropoff, delivered, canceled, returned, shopping_completed) —
      # stored verbatim, same last_status rationale as every sibling
      # mapping table in this project.
      t.string :last_status

      t.string :tracking_url
      t.string :courier_name
      t.string :courier_phone
      t.text :dispatch_error

      # Full response, for debugging/support visibility — same
      # jsonb/json Postgres-vs-SQLite branch as every sibling migration.
      if t.respond_to?(:jsonb)
        t.jsonb :raw_response
      else
        t.json :raw_response
      end

      t.timestamps
    end

    add_index :spree_uber_direct_delivery_mappings, :external_delivery_id, unique: true
  end
end
