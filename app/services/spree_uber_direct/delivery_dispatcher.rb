module SpreeUberDirect
  # Dispatches a completed order to Uber Direct: creates the delivery
  # against its already-open quote if one exists and hasn't expired, or
  # requests a fresh quote and creates the delivery from that instead.
  # Same accept-or-requote shape as SpreeDoordash::DeliveryDispatcher, for
  # the identical reason — checkout can easily outlast a quote's validity
  # window (Uber returns its own real `expires` per quote; see
  # SpreeUberDirect::QuoteMapping#expired?).
  class DeliveryDispatcher
    def self.call(...) = new.call(...)

    def call(order)
      quote_mapping = quote_mapping_for(order)
      return nil unless quote_mapping

      client = SpreeUberDirect::Client.for_store(order.store || Spree::Store.default)
      response = client.create_delivery(quote_id: quote_mapping.external_quote_id)

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
