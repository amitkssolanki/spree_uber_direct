module SpreeUberDirect
  # Applies an Uber Direct delivery-status webhook event to the mapped
  # Spree order — the Uber Direct analog of SpreeDoordash::DeliveryStatusMapper.
  #
  # Uber's own status vocabulary (confirmed directly against the real
  # openapi.yaml shipped in uber/uber-direct-sdk, not assumed): `pending`,
  # `pickup` / `pickup_complete`, `dropoff`, `delivered`, `canceled`,
  # `returned`, plus `shopping_completed` for Courier Pick & Pack orders
  # (not used by this extension's own flow, but present in the schema).
  #
  # No version/sequence field in Uber's payload either, same "don't gate on
  # ordering" posture as both DoorDash's and Square's own status mappers —
  # safety against duplicate processing comes entirely from WebhookEvent's
  # idempotency key and from the state-guarded, idempotent operations
  # below. Uber's own webhook ordering behavior across concurrent workers
  # is unverified until actually observed live — flagged here rather than
  # assumed, same precedent as every sibling status mapper's own comment.
  class DeliveryStatusMapper
    SHIP_STATUSES = %w[delivered].freeze
    CANCEL_STATUSES = %w[canceled returned].freeze
    # Real Uber lifecycle statuses with no Spree shipment_state equivalent
    # — recorded as a friendly last_status label only, same "label vs.
    # state transition" split as every sibling status mapper.
    LABEL_ONLY_STATUSES = %w[pending pickup pickup_complete dropoff shopping_completed].freeze

    def self.call(...) = new.call(...)

    def call(payload)
      mapping = SpreeUberDirect::DeliveryMapping.find_by(external_delivery_id: payload['delivery_id'])
      return unless mapping

      status = payload['status']
      order = mapping.order
      data = payload['data'] || {}
      courier = data['courier'] || {}

      case status
      when *SHIP_STATUSES
        ship!(order)
      when *CANCEL_STATUSES
        cancel!(order)
      when *LABEL_ONLY_STATUSES
        # No Spree-side transition — last_status below is the only effect.
      end

      # tracking_url isn't confirmed present on the webhook payload itself
      # (the real Delivery Status Webhook reference documents delivery_id/
      # status/data.courier/data.pickup/data.dropoff/batch_id/
      # courier_imminent — tracking_url is a top-level field on the fuller
      # CreateDeliveryResp/GetDeliveryResp REST shapes, which webhooks
      # often trim). `.presence || mapping.tracking_url` means a missing
      # field here just keeps whatever DeliveryDispatcher already recorded
      # from the create_delivery response, rather than clobbering it with
      # nil — safe either way, verify the real key at M4's live test.
      mapping.update!(
        last_status: status || mapping.last_status,
        tracking_url: data['tracking_url'].presence || mapping.tracking_url,
        courier_name: courier['name'].presence || mapping.courier_name,
        courier_phone: courier['phone_number'].presence || mapping.courier_phone
      )
    end

    private

    def ship!(order)
      order.shipments.each { |shipment| shipment.ship! if shipment.ready? }
    end

    def cancel!(order)
      order.cancel! unless order.canceled?
    end
  end
end
