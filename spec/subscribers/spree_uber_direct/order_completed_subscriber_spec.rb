RSpec.describe SpreeUberDirect::OrderCompletedSubscriber do
  describe 'registration' do
    # Same real gap found live in spree_doordash before it carried this
    # fix — Spree::Subscriber's own docstring claims subscribers are
    # "automatically registered during Rails initialization," but
    # spree_core 5.6.1's Spree::Events.register_subscribers! only ever
    # iterates the explicit Spree.subscribers array. Every other test in
    # this file calls `described_class.call(event)` directly, which would
    # keep passing even if this class were never wired to the real
    # 'order.completed' event at all.
    it 'is registered with Spree so it actually receives real order.completed events' do
      expect(Spree.subscribers).to include(described_class)
    end
  end

  describe '.call' do
    it 'enqueues a DeliveryDispatchJob when the order was fulfilled via an Uber Direct Delivery shipping method' do
      uber_method = create(:shipping_method, calculator: Spree::Calculator::Shipping::UberDirectQuote.new)
      order = create(:order)
      shipment = create(:shipment, order: order)
      rate = shipment.add_shipping_method(uber_method, true)
      shipment.selected_shipping_rate_id = rate.id

      event = Spree::Event.new(name: 'order.completed', payload: { 'id' => order.to_param })

      expect(SpreeUberDirect::DeliveryDispatchJob).to receive(:perform_later).with(order.id)

      described_class.call(event)
    end

    it 'is a safe no-op for an order fulfilled via a non-Uber-Direct shipping method' do
      order = create(:order)
      create(:shipment, order: order)

      event = Spree::Event.new(name: 'order.completed', payload: { 'id' => order.to_param })

      expect(SpreeUberDirect::DeliveryDispatchJob).not_to receive(:perform_later)

      described_class.call(event)
    end

    it 'is a safe no-op when the payload id does not resolve to a real order' do
      event = Spree::Event.new(name: 'order.completed', payload: { 'id' => 'or_doesnotexist' })

      expect(SpreeUberDirect::DeliveryDispatchJob).not_to receive(:perform_later)

      expect { described_class.call(event) }.not_to raise_error
    end
  end
end
