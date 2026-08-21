module SpreeUberDirect
  # Idempotency + audit log for inbound Uber Direct webhook notifications.
  #
  # Column named `status` on this table is Uber's own delivery status value
  # (pending/pickup/pickup_complete/dropoff/delivered/canceled/returned/
  # shopping_completed) — this model's *own* pending/processed/failed
  # processing state lives in the separate `processing_status` column, to
  # avoid the two genuinely different meanings colliding on one name
  # (DoorDash's own WebhookEvent didn't need this distinction since its
  # payload field is called event_name, not status).
  class WebhookEvent < Spree.base_class
    self.table_name = 'spree_uber_direct_webhook_events'

    attribute :payload, default: -> { {} }

    validates :delivery_id, presence: true
    validates :status, presence: true
    validates :payload_digest, presence: true, uniqueness: { scope: %i[delivery_id status] }

    scope :pending, -> { where(processing_status: 'pending') }

    def self.digest(raw_body)
      Digest::SHA256.hexdigest(raw_body)
    end

    def mark_processed!
      update!(processing_status: 'processed', processed_at: Time.current)
    end

    def mark_failed!(error)
      update!(processing_status: 'failed', processed_at: Time.current, error_message: error.to_s.truncate(1000))
    end
  end
end
