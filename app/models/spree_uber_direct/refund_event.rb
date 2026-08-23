module SpreeUberDirect
  # Durable, unprocessed record of an inbound `event.refund_request`
  # webhook. Uber Direct's refund-request payloads carry no top-level
  # `status`, so WebhooksController can't build a WebhookEvent from one
  # (see that model's own comment) — before this, they were acked and
  # silently dropped alongside genuinely-disposable courier_update pings,
  # even though refund data (data.id, currency_code,
  # total_partner_refund, total_uber_refund, refund_fees,
  # refund_order_items) can't be recovered later once thrown away.
  #
  # Intentionally does none of WebhookEvent's processing-state tracking
  # (processing_status/processed_at/error_message) — there's no consumer
  # for this data yet. It exists purely so refund reconciliation admin UI
  # or accounting sync has something real to read from whenever it's
  # built.
  #
  # Does keep WebhookEvent's idempotency-key shape though (delivery_id +
  # a digest of the raw body) — Uber's webhook delivery is at-least-once,
  # and a retried refund_request shouldn't silently become two rows for
  # the same refund.
  class RefundEvent < Spree.base_class
    self.table_name = 'spree_uber_direct_refund_events'

    attribute :payload, default: -> { {} }

    validates :delivery_id, presence: true
    validates :payload, presence: true
    validates :payload_digest, presence: true, uniqueness: { scope: :delivery_id }

    def self.digest(raw_body)
      Digest::SHA256.hexdigest(raw_body)
    end
  end
end
