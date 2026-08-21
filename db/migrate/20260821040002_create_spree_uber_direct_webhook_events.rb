class CreateSpreeUberDirectWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_uber_direct_webhook_events do |t|
      # Uber Direct's webhook payload has a single event `kind`
      # (event.delivery_status for every status change — confirmed
      # directly against the real webhook reference, not assumed) rather
      # than a distinct event id, same shape gap DoorDash's own webhooks
      # have. The idempotency key is built the identical way
      # SpreeDoordash::WebhookEvent's own migration explains: delivery_id +
      # status (which transition this is) + a digest of the raw body
      # (guards against two genuinely different payloads sharing those two
      # fields).
      t.string :delivery_id, null: false
      t.string :status, null: false
      t.string :payload_digest, null: false

      # jsonb on Postgres, json on SQLite — same rationale (and the same
      # real Postgres-only `SELECT DISTINCT` admin-listing bug this
      # pattern was already found live for) as every sibling migration in
      # this project.
      if t.respond_to?(:jsonb)
        t.jsonb :payload, null: false
      else
        t.json :payload, null: false
      end
      t.datetime :processed_at
      t.string :processing_status, null: false, default: 'pending' # pending, processed, failed
      t.text :error_message

      t.timestamps
    end

    add_index :spree_uber_direct_webhook_events, %i[delivery_id status payload_digest],
              unique: true, name: 'index_spree_uber_direct_webhook_events_on_idempotency_key'
    add_index :spree_uber_direct_webhook_events, :status
  end
end
