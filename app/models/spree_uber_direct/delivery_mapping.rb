module SpreeUberDirect
  # Maps a Spree::Order to the Uber Direct delivery it was dispatched to on
  # acceptance — the Uber Direct analog of SpreeDoordash::DeliveryMapping.
  # Unlike DoorDash (which reuses the accepted quote's own id for the
  # delivery's whole lifecycle), Uber mints a genuinely separate
  # `del_`-prefixed id on POST /deliveries (confirmed directly against the
  # real CreateDeliveryResp schema) — external_delivery_id here is always
  # that new id, never the quote's `dqt_...` id.
  class DeliveryMapping < Spree.base_class
    self.table_name = 'spree_uber_direct_delivery_mappings'

    belongs_to :order, class_name: 'Spree::Order'

    validates :order, presence: true, uniqueness: true
    # No presence requirement, allow_nil on uniqueness — same rationale as
    # SpreeDoordash::DeliveryMapping's own external_delivery_id: a dispatch
    # can fail before Uber ever returns a delivery id at all (e.g. the
    # underlying quote itself failed), and DeliveryDispatchJob's
    # dead-letter block still needs to record that failure on a row with
    # no id yet.
    validates :external_delivery_id, uniqueness: true, allow_nil: true

    def mark_failed!(error)
      update!(dispatch_error: error.to_s.truncate(2000))
    end
  end
end
