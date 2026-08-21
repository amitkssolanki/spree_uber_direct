RSpec.describe SpreeUberDirect::Client do
  let!(:credential) { create(:uber_direct_credential, store: store) }
  let(:store) { create(:store) }

  def stub_token(access_token: 'fresh-token', expires_in: 3600)
    stub_request(:post, 'https://auth.uber.com/oauth/v2/token')
      .to_return(
        status: 200,
        body: { access_token: access_token, expires_in: expires_in, token_type: 'Bearer' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '.instance / .for_store' do
    it 'raises MissingCredentialsError when the store has no connected credential and no ENV fallback' do
      expect { described_class.for_store(create(:store)) }.to raise_error(described_class::MissingCredentialsError)
    end

    it 'resolves against the given store credential' do
      client = described_class.for_store(store)
      expect(client).to be_sandbox
    end

    it 're-resolves the credential on every call rather than caching the client instance' do
      described_class.for_store(store)
      credential.destroy!
      expect { described_class.for_store(store) }.to raise_error(described_class::MissingCredentialsError)
    end
  end

  describe 'OAuth token fetch and caching' do
    it 'requests a token via client_credentials with the eats.deliveries scope' do
      stub_token
      quote_stub = stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/delivery_quotes")
                   .with { |req|
                     expect(req.headers['Authorization']).to eq('Bearer fresh-token')
                     true
                   }
                   .to_return(status: 200, body: { id: 'quote_1', fee: 599 }.to_json, headers: { 'Content-Type' => 'application/json' })

      described_class.for_store(store).create_quote({})

      expect(
        a_request(:post, 'https://auth.uber.com/oauth/v2/token').with(
          body: hash_including('client_id' => credential.client_id, 'client_secret' => credential.client_secret, 'grant_type' => 'client_credentials', 'scope' => 'eats.deliveries')
        )
      ).to have_been_made
      expect(quote_stub).to have_been_requested
    end

    it 'caches the fetched token on the credential row' do
      stub_token(access_token: 'cached-me')
      stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/delivery_quotes")
        .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

      described_class.for_store(store).create_quote({})

      expect(credential.reload.access_token).to eq('cached-me')
      expect(credential.access_token_expires_at).to be_present
    end

    it 'reuses a cached, still-valid token instead of fetching a new one' do
      credential.update!(access_token: 'still-valid', access_token_expires_at: 1.hour.from_now)
      quote_stub = stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/delivery_quotes")
                   .with(headers: { 'Authorization' => 'Bearer still-valid' })
                   .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

      described_class.for_store(store).create_quote({})

      expect(quote_stub).to have_been_requested
      expect(a_request(:post, 'https://auth.uber.com/oauth/v2/token')).not_to have_been_made
    end

    it 'fetches a fresh token when the cached one is past its refresh margin' do
      credential.update!(access_token: 'stale', access_token_expires_at: 10.seconds.from_now)
      token_stub = stub_token(access_token: 'renewed')
      stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/delivery_quotes")
        .with(headers: { 'Authorization' => 'Bearer renewed' })
        .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

      described_class.for_store(store).create_quote({})

      expect(token_stub).to have_been_requested
      expect(credential.reload.access_token).to eq('renewed')
    end

    it 'raises RequestError when the OAuth token endpoint itself fails' do
      stub_request(:post, 'https://auth.uber.com/oauth/v2/token')
        .to_return(status: 401, body: { error: 'invalid_client' }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect { described_class.for_store(store).create_quote({}) }.to raise_error(SpreeUberDirect::RequestError) do |error|
        expect(error.status).to eq(401)
      end
    end
  end

  describe 'API calls' do
    before { stub_token }

    it '#create_quote posts to /v1/customers/{customer_id}/delivery_quotes' do
      stub = stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/delivery_quotes")
             .with(body: { pickup_address: 'x' }.to_json)
             .to_return(status: 200, body: { id: 'quote_1' }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = described_class.for_store(store).create_quote(pickup_address: 'x')

      expect(stub).to have_been_requested
      expect(result['id']).to eq('quote_1')
    end

    it '#create_delivery posts to /v1/customers/{customer_id}/deliveries' do
      stub = stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/deliveries")
             .to_return(status: 200, body: { id: 'del_1', status: 'pending' }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = described_class.for_store(store).create_delivery(quote_id: 'quote_1')

      expect(stub).to have_been_requested
      expect(result['status']).to eq('pending')
    end

    it '#get_delivery gets /v1/customers/{customer_id}/deliveries/{id}' do
      stub = stub_request(:get, "https://api.uber.com/v1/customers/#{credential.customer_id}/deliveries/del_1")
             .to_return(status: 200, body: { id: 'del_1', status: 'delivered' }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = described_class.for_store(store).get_delivery('del_1')

      expect(stub).to have_been_requested
      expect(result['status']).to eq('delivered')
    end

    it '#cancel_delivery posts to /v1/customers/{customer_id}/deliveries/{id}/cancel' do
      stub = stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/deliveries/del_1/cancel")
             .to_return(status: 200, body: { id: 'del_1', status: 'canceled' }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = described_class.for_store(store).cancel_delivery('del_1')

      expect(stub).to have_been_requested
      expect(result['status']).to eq('canceled')
    end

    it 'raises RequestError with the status and parsed body on a non-2xx response' do
      stub_request(:post, "https://api.uber.com/v1/customers/#{credential.customer_id}/delivery_quotes")
        .to_return(status: 422, body: { code: 'unserviceable_area' }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect { described_class.for_store(store).create_quote({}) }.to raise_error(SpreeUberDirect::RequestError) do |error|
        expect(error.status).to eq(422)
        expect(error.body['code']).to eq('unserviceable_area')
      end
    end
  end
end
