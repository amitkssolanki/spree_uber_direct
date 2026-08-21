FactoryBot.define do
  # Define your Spree extensions Factories within this file to enable applications, and other extensions to use and override them.
  #
  # Example adding this to your spec_helper will load these Factories for use:
  # require 'spree_uber_direct/factories'

  factory :uber_direct_credential, class: 'SpreeUberDirect::Credential' do
    store
    client_id { 'test-client-id' }
    client_secret { 'test-client-secret' }
    customer_id { 'test-customer-id' }
    uber_environment { 'sandbox' }
    webhook_signing_secret { 'test-webhook-signing-secret' }
  end

  factory :uber_direct_quote_mapping, class: 'SpreeUberDirect::QuoteMapping' do
    order
    sequence(:external_quote_id) { |i| "dqt_#{i}" }
    quoted_fee_cents { 599 }
    currency { 'USD' }
    quote_expires_at { 15.minutes.from_now }
  end

  factory :uber_direct_delivery_mapping, class: 'SpreeUberDirect::DeliveryMapping' do
    order
    sequence(:external_delivery_id) { |i| "del_#{i}" }
    last_status { 'pending' }
    tracking_url { 'https://www.ubereats.com/orders/abc123' }
  end

  factory :uber_direct_webhook_event, class: 'SpreeUberDirect::WebhookEvent' do
    sequence(:delivery_id) { |i| "del_#{i}" }
    status { 'pickup' }
    sequence(:payload_digest) { |i| "digest-#{i}" }
    payload { { 'delivery_id' => 'del_1', 'status' => 'pickup' } }
  end
end
