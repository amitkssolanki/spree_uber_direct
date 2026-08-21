require_dependency 'spree/shipping_calculator'

module Spree
  # Compact `module Calculator::Shipping` — same reasoning as
  # Spree::Calculator::Shipping::DoordashQuote's own docstring:
  # Spree::Calculator is already a class in spree_core, not a module;
  # nesting it the "obvious" way raises TypeError.
  module Calculator::Shipping
    # Prices an "Uber Direct Delivery" shipping method against a real,
    # live Uber Direct quote rather than a flat/configured rate. Same
    # zero-registration mechanism as DoordashQuote — any
    # < Spree::ShippingCalculator subclass is auto-discovered by
    # Spree::Stock::Estimator, confirmed directly against spree_core's own
    # shipping_method.rb.
    class UberDirectQuote < ShippingCalculator
      def self.description
        'Uber Direct (live quote)'
      end

      def compute_package(package)
        result = SpreeUberDirect::Quote.call(package.order)
        if result.nil?
          # Same object-identity bridge DoordashQuote's own compute_package
          # needs, for the identical reason: `package.order` is not the
          # same in-memory object `create_proposed_shipments` holds as
          # `self` (spree_core's InventoryUnitBuilder deliberately defers
          # loading that association) — a direct
          # `package.order.warnings |= [...]` here would silently mutate a
          # throwaway copy discarded the instant this method returns. See
          # SpreeUberDirect::OrderDecorator for the merge-back half of this
          # bridge, and spree_doordash's own CHANGELOG (0.1.3) for the full
          # story of how this was originally found live.
          self.class.mark_unavailable(package.order.id)
          return nil
        end

        result.fee_cents / 100.0
      end

      def self.mark_unavailable(order_id)
        (Thread.current[:spree_uber_direct_quote_unavailable_order_ids] ||= []) << order_id
      end

      def self.unavailable?(order_id)
        Thread.current[:spree_uber_direct_quote_unavailable_order_ids]&.include?(order_id) || false
      end

      def self.clear_unavailable(order_id)
        Thread.current[:spree_uber_direct_quote_unavailable_order_ids]&.delete(order_id)
      end

      # Called by Estimator to filter which shipping methods even attempt
      # a compute_package call. Skips the Uber Direct API round-trip
      # entirely for an order with no ship address yet — the real "can
      # Uber Direct serve this address" check still happens inside
      # SpreeUberDirect::Quote itself.
      def available?(package)
        package.order.ship_address.present?
      end
    end
  end
end
