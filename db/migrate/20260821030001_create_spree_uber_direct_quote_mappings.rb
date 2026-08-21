class CreateSpreeUberDirectQuoteMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_uber_direct_quote_mappings do |t|
      t.references :order, null: false, foreign_key: { to_table: :spree_orders }, index: { unique: true }

      # Uber's own — returned as `id` on the DeliveryQuoteResp (always
      # prefixed `dqt_`). Unlike SpreeDoordash::QuoteMapping's
      # external_delivery_id (client-generated, sent in the *request*,
      # which is why DoorDash needed a random suffix per attempt to dodge
      # its own 409 duplicate_delivery_id), Uber mints this server-side and
      # returns a fresh one on every /delivery_quotes call — no collision
      # risk to guard against, re-quoting is always safe.
      t.string :external_quote_id, null: false

      t.integer :quoted_fee_cents
      # currency_type (uppercase ISO), not the deprecated lowercase
      # `currency` field DeliveryQuoteResp also returns — see
      # SpreeUberDirect::Quote.
      t.string :currency, default: 'USD'

      # Uber returns its own real expiry (`expires`) on every quote — no
      # need to hardcode a documented window the way DoorDash's 5-minute
      # rule required (SpreeDoordash::QuoteMapping had no `expires` field
      # to read at all).
      t.datetime :quote_expires_at

      # `duration`/`pickup_duration` on DeliveryQuoteResp are estimates in
      # minutes, not timestamps — `dropoff_eta` is the one real (RFC 3339)
      # timestamp field.
      t.integer :duration_minutes_estimated
      t.integer :pickup_duration_minutes_estimated
      t.datetime :dropoff_eta_estimated

      # Full response, for debugging/support visibility — same rationale
      # (and same jsonb/json Postgres-vs-SQLite branch) as
      # SpreeDoordash::QuoteMapping#raw_response.
      if t.respond_to?(:jsonb)
        t.jsonb :raw_response
      else
        t.json :raw_response
      end

      t.timestamps
    end

    add_index :spree_uber_direct_quote_mappings, :external_quote_id, unique: true
  end
end
