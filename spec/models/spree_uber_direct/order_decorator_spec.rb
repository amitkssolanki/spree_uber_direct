RSpec.describe 'SpreeUberDirect::OrderDecorator', type: :model do
  # Same real-integration-path rationale as spree_doordash's own
  # order_decorator_spec.rb — deliberately goes through the real
  # order_routing_strategy -> Estimator -> Packer -> InventoryUnitBuilder
  # path (not a stubbed Package double) so the object-identity boundary
  # the fix bridges across is actually exercised. Only
  # SpreeUberDirect::Quote.call is stubbed.
  let(:order) { create(:order_with_line_items, line_items_count: 1) }

  before do
    shipping_category = order.line_items.first.variant.shipping_category
    create(
      :shipping_method,
      calculator: Spree::Calculator::Shipping::UberDirectQuote.new,
      shipping_categories: [shipping_category],
      zones: [Spree::Zone.global]
    )
    order.shipments.destroy_all
  end

  describe '#create_proposed_shipments' do
    it 'merges the uber_direct_quote_unavailable warning onto the real order when the quote fails' do
      allow(SpreeUberDirect::Quote).to receive(:call).and_return(nil)

      order.create_proposed_shipments

      expect(order.warnings.map { |w| w[:code] }).to include('uber_direct_quote_unavailable')
    end

    it 'does not add a warning when the quote succeeds' do
      allow(SpreeUberDirect::Quote).to receive(:call).and_return(
        SpreeUberDirect::Quote::Result.new(fee_cents: 799, currency: 'USD', external_quote_id: 'dqt_x', expires_at: Time.current)
      )

      order.create_proposed_shipments

      expect(order.warnings).to be_empty
    end

    it 'clears the thread-local flag after merging, so it does not leak into a later, unrelated recomputation' do
      allow(SpreeUberDirect::Quote).to receive(:call).and_return(nil)

      order.create_proposed_shipments

      expect(Spree::Calculator::Shipping::UberDirectQuote.unavailable?(order.id)).to be false
    end

    it 'clears a stale flag left behind by an earlier, incomplete call before doing anything else' do
      Spree::Calculator::Shipping::UberDirectQuote.mark_unavailable(order.id)
      allow(SpreeUberDirect::Quote).to receive(:call).and_return(
        SpreeUberDirect::Quote::Result.new(fee_cents: 799, currency: 'USD', external_quote_id: 'dqt_x', expires_at: Time.current)
      )

      order.create_proposed_shipments

      expect(order.warnings).to be_empty
    end

    it 'does not add a warning for an order with no Uber Direct shipping method at all' do
      other_category = create(:shipping_category, name: 'Unrelated category')
      other_product = create(:product, shipping_category: other_category)
      other_order = create(:order_with_line_items, variants: [other_product.master])
      allow(SpreeUberDirect::Quote).to receive(:call).and_return(nil)

      other_order.create_proposed_shipments

      expect(other_order.warnings).to be_empty
    end
  end
end

# Coexistence with spree_doordash's own Spree::OrderDecorator (confirms the
# distinct-module-name choice above actually avoids the collision it's
# meant to avoid) can only be exercised where both gems are installed
# together — spree_host, not this gem's own isolated dummy app. Verified
# live there instead; see this gem's CHANGELOG.
