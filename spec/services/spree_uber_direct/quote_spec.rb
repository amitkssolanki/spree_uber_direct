RSpec.describe SpreeUberDirect::Quote do
  let(:store) { create(:store) }
  let(:stock_location) { create(:stock_location, name: 'Downtown Branch', phone: '+14155550100') }
  let!(:credential) { create(:uber_direct_credential, store: store) }
  let(:order) do
    create(:order, store: store, ship_address: create(:address, phone: '+14155550199'))
  end
  let!(:shipment) { create(:shipment, order: order, stock_location: stock_location) }

  def stub_token
    stub_request(:post, 'https://auth.uber.com/oauth/v2/token')
      .to_return(status: 200, body: { access_token: 'test-token', expires_in: 3600 }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  def stub_quote(fee: 599, status: 200, expires: 15.minutes.from_now.iso8601)
    stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/delivery_quotes")
      .to_return(
        status: status,
        body: { id: 'dqt_abc123', fee: fee, currency_type: 'USD', expires: expires,
                duration: 33, pickup_duration: 12, dropoff_eta: 20.minutes.from_now.iso8601 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  before { stub_token }

  describe '.call' do
    it 'requests a quote and persists it on a QuoteMapping' do
      stub_quote(fee: 975)

      result = described_class.call(order)

      expect(result.fee_cents).to eq(975)
      expect(result.currency).to eq('USD')
      expect(result.external_quote_id).to eq('dqt_abc123')
      expect(result.expires_at).to be_present

      mapping = SpreeUberDirect::QuoteMapping.find_by(order: order)
      expect(mapping.quoted_fee_cents).to eq(975)
      expect(mapping.external_quote_id).to eq('dqt_abc123')
      expect(mapping.duration_minutes_estimated).to eq(33)
      expect(mapping.pickup_duration_minutes_estimated).to eq(12)
      expect(mapping.expired?).to be false
    end

    it 'sends the fulfilling stock location as pickup and the order ship_address as dropoff, as JSON-string addresses' do
      stub = stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/delivery_quotes")
             .with { |req|
               body = JSON.parse(req.body)
               pickup = JSON.parse(body['pickup_address'])
               dropoff = JSON.parse(body['dropoff_address'])
               expect(pickup['city']).to eq(stock_location.city)
               expect(dropoff['city']).to eq(order.ship_address.city)
               expect(pickup['street_address']).to be_an(Array)
               true
             }
             .to_return(status: 200, body: { id: 'dqt_1', fee: 599, currency_type: 'USD' }.to_json, headers: { 'Content-Type' => 'application/json' })

      described_class.call(order)

      expect(stub).to have_been_requested
    end

    it 'upserts the same QuoteMapping row on a re-quote for the same order (not a second row)' do
      stub_quote(fee: 599)
      described_class.call(order)
      stub_quote(fee: 650)
      described_class.call(order)

      expect(SpreeUberDirect::QuoteMapping.where(order: order).count).to eq(1)
      expect(SpreeUberDirect::QuoteMapping.find_by(order: order).quoted_fee_cents).to eq(650)
    end

    it 'returns nil (does not raise) when the store has no Uber Direct credential connected and no ENV fallback' do
      credential.destroy!
      expect(described_class.call(order)).to be_nil
    end

    it 'returns nil (does not raise) when Uber rejects the address as unserviceable' do
      stub_quote(fee: nil, status: 400)
      expect(described_class.call(order)).to be_nil
    end

    it 'returns nil (does not raise) when the fulfilling stock location has no phone' do
      stock_location.update!(phone: nil)
      stub = stub_quote
      expect(described_class.call(order)).to be_nil
      expect(stub).not_to have_been_requested
    end

    context 'with no phone on the ship address' do
      let(:order) do
        create(:order, store: store, ship_address: create(:address, phone: nil))
      end

      it 'returns nil without calling the Uber Direct API' do
        stub = stub_quote
        expect(described_class.call(order)).to be_nil
        expect(stub).not_to have_been_requested
      end
    end

    context 'with a phone number formatted the way a real checkout form produces it' do
      let(:order) do
        create(:order, store: store, ship_address: create(:address, phone: '(415) 555-0199'))
      end

      it 'normalizes both pickup and dropoff numbers to E.164 before calling Uber Direct' do
        stock_location.update!(phone: '(415) 555-0100')

        stub = stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/delivery_quotes")
               .with { |req|
                 body = JSON.parse(req.body)
                 expect(body['pickup_phone_number']).to eq('+14155550100')
                 expect(body['dropoff_phone_number']).to eq('+14155550199')
                 true
               }
               .to_return(status: 200, body: { id: 'dqt_1', fee: 599, currency_type: 'USD' }.to_json, headers: { 'Content-Type' => 'application/json' })

        described_class.call(order)

        expect(stub).to have_been_requested
      end
    end
  end
end
