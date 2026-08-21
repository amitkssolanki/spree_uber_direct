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
end
