class CreateSpreeUberDirectRefundEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_uber_direct_refund_events do |t|
      # `event.refund_request` webhooks carry no top-level `status` field
      # (see WebhooksController's own comment on that), so this is
      # deliberately a separate, simpler table rather than a WebhookEvent
      # row with a null status — the whole point is that refund data has
      # nowhere else to land and can't be recovered later if dropped.
      # Nothing here processes it yet: this is just a durable record of
      # what Uber actually sent (data.id, currency_code,
      # total_partner_refund, total_uber_refund, refund_fees,
      # refund_order_items — all captured for free inside `payload`), for
      # whenever refund reconciliation admin UI or accounting sync
      # actually needs it.
      t.string :delivery_id, null: false

      # jsonb on Postgres, json on SQLite — same rationale as every
      # sibling migration in this project (see WebhookEvent's own
      # migration comment for the Postgres-only `SELECT DISTINCT` bug this
      # pattern already avoided once).
      if t.respond_to?(:jsonb)
        t.jsonb :payload, null: false
      else
        t.json :payload, null: false
      end

      t.timestamps
    end

    add_index :spree_uber_direct_refund_events, :delivery_id
  end
end
