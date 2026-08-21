module SpreeUberDirect
  # Events & Subscribers is the preferred pattern for this kind of side
  # effect (per this app's own CLAUDE.md conventions) — react to
  # order.completed without touching Spree::Order itself. Mirrors
  # SpreeDoordash::OrderCompletedSubscriber's shape exactly; independent of
  # it and of spree_square's own subscriber on the same event — Spree's
  # Events system already fires all three separately for every order
  # (confirmed live earlier in this project: each shows up as its own
  # Spree::Events::SubscriberJob entry for the same event).
  class OrderCompletedSubscriber < Spree::Subscriber
    subscribes_to 'order.completed'

    def handle(event)
      order = Spree::Order.find_by_prefix_id(event.payload['id'])
      return unless order
      return unless uber_direct_delivery?(order)

      SpreeUberDirect::DeliveryDispatchJob.perform_later(order.id)
    end

    private

    # Only dispatch orders actually fulfilled via an "Uber Direct Delivery"
    # shipping method — pickup/DoorDash/other-carrier orders should never
    # reach Uber Direct at all.
    def uber_direct_delivery?(order)
      order.shipments.any? { |shipment| shipment.shipping_method&.calculator.is_a?(Spree::Calculator::Shipping::UberDirectQuote) }
    end
  end
end
