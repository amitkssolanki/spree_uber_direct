RSpec.describe SpreeUberDirect::DeliveryDispatcher do
  let(:store) { create(:store) }
  let(:stock_location) { create(:stock_location, name: 'Downtown Branch', phone: '+14155550100') }
  let!(:credential) { create(:uber_direct_credential, store: store) }
  let(:order) { create(:order, store: store, ship_address: create(:address, phone: '+14155550199')) }
  let!(:shipment) { create(:shipment, order: order, stock_location: stock_location) }

  def stub_token
    stub_request(:post, 'https://auth.uber.com/oauth/v2/token')
      .to_return(status: 200, body: { access_token: 'test-token', expires_in: 3600 }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  def stub_quote(fee: 599, status: 200)
    stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/delivery_quotes")
      .to_return(status: status, body: { id: 'dqt_fresh', fee: fee, currency_type: 'USD', expires: 15.minutes.from_now.iso8601 }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  def stub_create_delivery(quote_id:, status: 200)
    stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/deliveries")
      .with(body: hash_including('quote_id' => quote_id))
      .to_return(status: status, body: {
        id: 'del_abc', status: 'pending', tracking_url: 'https://www.ubereats.com/orders/abc',
        courier: nil
      }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  before { stub_token }

  describe '.call' do
    it 'creates a delivery from an existing, unexpired quote directly (no re-quote)' do
      existing = create(:uber_direct_quote_mapping, order: order, external_quote_id: 'dqt_existing', quote_expires_at: 10.minutes.from_now)
      create_stub = stub_create_delivery(quote_id: 'dqt_existing')

      result = described_class.call(order)

      expect(create_stub).to have_been_requested
      expect(result.external_delivery_id).to eq('del_abc')
      expect(SpreeUberDirect::DeliveryMapping.find_by(order: order)).to be_present
      expect(existing.reload.external_quote_id).to eq('dqt_existing') # untouched
    end

    it 're-quotes first when there is no existing quote, then creates the delivery from the fresh one' do
      quote_stub = stub_quote(fee: 975)
      create_stub = stub_create_delivery(quote_id: 'dqt_fresh')

      result = described_class.call(order)

      expect(quote_stub).to have_been_requested
      expect(create_stub).to have_been_requested
      expect(result.last_status).to eq('pending')
    end

    it 're-quotes when the existing quote has expired' do
      create(:uber_direct_quote_mapping, order: order, external_quote_id: 'dqt_stale', quote_expires_at: 1.minute.ago)
      quote_stub = stub_quote(fee: 650)
      create_stub = stub_create_delivery(quote_id: 'dqt_fresh')

      described_class.call(order)

      expect(quote_stub).to have_been_requested
      expect(create_stub).to have_been_requested
    end

    it 'returns nil and records the failure when create_delivery is rejected (e.g. quote expired on Uber\'s side)' do
      create(:uber_direct_quote_mapping, order: order, external_quote_id: 'dqt_expired', quote_expires_at: 10.minutes.from_now)
      stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/deliveries")
        .to_return(status: 422, body: { code: 'quote_expired' }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = described_class.call(order)

      expect(result).to be_nil
      mapping = SpreeUberDirect::DeliveryMapping.find_by(order: order)
      expect(mapping.dispatch_error).to be_present
    end

    it 'returns nil (does not raise) when there is no quote and no way to build one (no phone on the ship address)' do
      order.ship_address.update!(phone: nil)

      result = described_class.call(order)

      expect(result).to be_nil
    end

    it 'returns nil (does not raise) when the store has no Uber Direct credential connected' do
      credential.destroy!

      result = described_class.call(order)

      expect(result).to be_nil
    end

    it 'requests Robo Courier auto mode when the credential is sandbox (the default)' do
      create(:uber_direct_quote_mapping, order: order, external_quote_id: 'dqt_existing', quote_expires_at: 10.minutes.from_now)
      create_stub = stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/deliveries")
        .with(body: hash_including('quote_id' => 'dqt_existing', 'test_specifications' => { 'robo_courier_specification' => { 'mode' => 'auto' } }))
        .to_return(status: 200, body: { id: 'del_abc', status: 'pending', tracking_url: nil, courier: nil }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      described_class.call(order)

      expect(create_stub).to have_been_requested
    end

    it 'never requests Robo Courier when the credential is production' do
      credential.update!(uber_environment: 'production')
      create(:uber_direct_quote_mapping, order: order, external_quote_id: 'dqt_existing', quote_expires_at: 10.minutes.from_now)
      create_stub = stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/deliveries")
        .with { |req| !JSON.parse(req.body).key?('test_specifications') }
        .to_return(status: 200, body: { id: 'del_abc', status: 'pending', tracking_url: nil, courier: nil }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      described_class.call(order)

      expect(create_stub).to have_been_requested
    end
  end
end
