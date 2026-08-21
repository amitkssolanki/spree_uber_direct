module SpreeUberDirect
  # Requests a live Uber Direct delivery-fee quote for an order — the
  # storefront-facing half of this extension (called from
  # Spree::Calculator::Shipping::UberDirectQuote during checkout, M3) and
  # again at order.completed if the original quote expired (see
  # DeliveryDispatcher, M4).
  #
  # `order.total` at whichever moment this is called is what's sent as
  # manifest_total_value — Spree recalculates on every checkout step
  # already, and Uber isn't in the money path (Spree's own payment method
  # still charges the customer; Uber only uses this for delivery-fee/
  # insurance math) — same rationale SpreeDoordash::Quote documents for its
  # own order_value field.
  class Quote
    Result = Struct.new(:fee_cents, :currency, :external_quote_id, :expires_at, keyword_init: true)

    def self.call(...) = new.call(...)

    def call(order)
      return nil unless order.ship_address
      # Same real bug DoorDash's own Quote hit live: with no phone on the
      # ship address, the request is doomed before it's even sent —
      # Uber's own schema requires `^\+[0-9]+$` on both phone fields.
      # Spree::Config[:address_requires_phone] (spree_host) should make
      # this unreachable in the normal storefront checkout flow, but this
      # guard stays as defense in depth for any other path that can create
      # an order (admin, API, migrated data).
      return nil if order.ship_address.phone.blank?

      stock_location = pickup_location_for(order)
      return nil unless stock_location&.phone.present?

      client = SpreeUberDirect::Client.for_store(order.store || Spree::Store.default)
      response = client.create_quote(build_payload(order, stock_location))
      mapping = persist_quote!(order, response)

      Result.new(
        fee_cents: mapping.quoted_fee_cents,
        currency: mapping.currency,
        external_quote_id: mapping.external_quote_id,
        expires_at: mapping.quote_expires_at
      )
    rescue SpreeUberDirect::Client::MissingCredentialsError, SpreeUberDirect::RequestError => e
      # Unserviceable address, no credential connected, Uber-side rejection
      # — none of these should ever raise into checkout. The calculator
      # (M3) treats a nil Result as "this rate isn't available," Spree's
      # normal shape for "can't quote this," same as
      # Spree::Calculator::Shipping::DoordashQuote's own precedent.
      Rails.logger.info("[SpreeUberDirect] quote skipped for order #{order.number}: #{e.message}")
      nil
    end

    private

    # Queried directly rather than `order.shipments.first` — same reasoning
    # as SpreeDoordash::Quote#location_mapping_for: a shipment created by
    # setting the FK directly (as spec factories and some checkout code
    # paths do) doesn't invalidate an already-loaded `order` object's
    # cached `shipments` association. No LocationMapping join needed here
    # at all (unlike DoorDash) — Uber Direct has no separate store/location
    # registration step; the pickup address is read straight off
    # Spree::StockLocation.
    def pickup_location_for(order)
      Spree::Shipment.where(order_id: order.id).first&.stock_location ||
        Spree::StockLocation.find_by(default: true)
    end

    def build_payload(order, stock_location)
      {
        pickup_address: AddressPayload.format_address(stock_location),
        pickup_phone_number: AddressPayload.format_phone(stock_location.phone),
        dropoff_address: AddressPayload.format_address(order.ship_address),
        dropoff_phone_number: AddressPayload.format_phone(order.ship_address.phone),
        manifest_total_value: (order.total * 100).to_i
      }
    end

    def persist_quote!(order, response)
      mapping = SpreeUberDirect::QuoteMapping.find_or_initialize_by(order: order)
      mapping.update!(
        external_quote_id: response['id'],
        quoted_fee_cents: response['fee'],
        currency: response['currency_type'] || 'USD',
        quote_expires_at: parse_time(response['expires']),
        duration_minutes_estimated: response['duration'],
        pickup_duration_minutes_estimated: response['pickup_duration'],
        dropoff_eta_estimated: parse_time(response['dropoff_eta']),
        raw_response: response
      )
      mapping
    end

    def parse_time(value)
      value.present? ? Time.iso8601(value) : nil
    end
  end
end
