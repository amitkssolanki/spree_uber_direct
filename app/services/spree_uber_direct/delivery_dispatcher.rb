module SpreeUberDirect
  # Dispatches a completed order to Uber Direct: creates the delivery
  # against its already-open quote if one exists and hasn't expired, or
  # requests a fresh quote and creates the delivery from that instead.
  # Same accept-or-requote shape as SpreeDoordash::DeliveryDispatcher, for
  # the identical reason — checkout can easily outlast a quote's validity
  # window (Uber returns its own real `expires` per quote; see
  # SpreeUberDirect::QuoteMapping#expired?).
  #
  # Architecturally bigger than DoorDash's own accept_quote (which only
  # needs the external_delivery_id, DoorDash already has everything else
  # from the original quote request) — confirmed live against a real
  # Sandbox 400: Uber's POST /deliveries wants a *full* DeliveryReq body
  # (pickup/dropoff name+address+phone, manifest_items,
  # manifest_total_value) even when a quote_id is also provided. Reuses
  # AddressPayload (shared with Quote) rather than duplicating the
  # formatting logic.
  class DeliveryDispatcher
    def self.call(...) = new.call(...)

    def call(order)
      quote_mapping = quote_mapping_for(order)
      return nil unless quote_mapping

      stock_location = pickup_location_for(order)
      return nil unless stock_location

      client = SpreeUberDirect::Client.for_store(order.store || Spree::Store.default)
      response = client.create_delivery(build_payload(order, stock_location, quote_mapping, sandbox: client.sandbox?))

      persist_delivery!(order, response)
    rescue SpreeUberDirect::Client::MissingCredentialsError, SpreeUberDirect::RequestError => e
      Rails.logger.error("[SpreeUberDirect] dispatch failed for order #{order.number}: #{e.message}")
      SpreeUberDirect::DeliveryMapping.find_or_initialize_by(order: order).mark_failed!(e)
      SpreeUberDirect::Alerting.capture(e, context: { area: 'dispatch', order_number: order.number })
      nil
    end

    private

    def quote_mapping_for(order)
      existing = SpreeUberDirect::QuoteMapping.find_by(order: order)
      return existing if existing && !existing.expired?

      SpreeUberDirect::Quote.call(order)
      SpreeUberDirect::QuoteMapping.find_by(order: order)
    end

    # Same lookup as SpreeUberDirect::Quote#pickup_location_for — queried
    # directly rather than trusting an already-loaded `order.shipments`
    # association, same reasoning.
    def pickup_location_for(order)
      Spree::Shipment.where(order_id: order.id).first&.stock_location ||
        Spree::StockLocation.find_by(default: true)
    end

    def build_payload(order, stock_location, quote_mapping, sandbox:)
      payload = {
        quote_id: quote_mapping.external_quote_id,
        pickup_name: stock_location.name,
        pickup_address: AddressPayload.format_address(stock_location),
        pickup_phone_number: AddressPayload.format_phone(stock_location.phone),
        dropoff_name: order.ship_address.full_name,
        dropoff_address: AddressPayload.format_address(order.ship_address),
        dropoff_phone_number: AddressPayload.format_phone(order.ship_address.phone),
        manifest_items: manifest_items(order),
        manifest_total_value: (order.total * 100).to_i
      }
      # Robo Courier: Uber Direct's sandbox-only test-automation feature —
      # there is no dashboard "simulate delivery" UI the way DoorDash has
      # one. Requesting `mode: 'auto'` here makes Uber's own courier bot
      # walk the delivery through real status transitions (assigned →
      # enroute → pickup imminent → picked up → dropoff imminent →
      # delivered) at fixed 30s intervals, firing a real webhook at each
      # stage. Never sent outside sandbox — a real courier fulfills a real
      # delivery in production and must not be short-circuited.
      payload[:test_specifications] = { robo_courier_specification: { mode: 'auto' } } if sandbox
      payload
    end

    def manifest_items(order)
      order.line_items.map do |item|
        { name: item.name, quantity: item.quantity }
      end
    end

    def persist_delivery!(order, response)
      courier = response['courier'] || {}
      mapping = SpreeUberDirect::DeliveryMapping.find_or_initialize_by(order: order)
      mapping.update!(
        external_delivery_id: response['id'],
        last_status: response['status'],
        tracking_url: response['tracking_url'],
        courier_name: courier['name'],
        courier_phone: courier['phone_number'],
        raw_response: response
      )
      mapping
    end
  end
end
