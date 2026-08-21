RSpec.describe 'SpreeUberDirect webhooks', type: :request do
  let(:secret) { 'test-webhook-signing-secret' }
  let(:path) { '/spree_uber_direct/webhooks/uber_direct' }
  let(:body) { { delivery_id: 'del_1', status: 'pickup' }.to_json }
  let(:valid_signature) { OpenSSL::HMAC.hexdigest('SHA256', secret, body) }

  before do
    store = create(:store, default: true)
    create(:uber_direct_credential, store: store, webhook_signing_secret: secret)
  end

  def headers(signature: valid_signature)
    { 'x-uber-signature' => signature, 'CONTENT_TYPE' => 'application/json' }
  end

  it 'accepts a correctly signed payload and enqueues the delivery webhook job' do
    expect(SpreeUberDirect::DeliveryWebhookJob).to receive(:perform_later)

    post path, params: body, headers: headers

    expect(response).to have_http_status(:ok)
    expect(SpreeUberDirect::WebhookEvent.find_by(delivery_id: 'del_1', status: 'pickup')).to be_present
  end

  it 'rejects a request with an incorrect signature' do
    post path, params: body, headers: headers(signature: 'a' * 64)

    expect(response).to have_http_status(:unauthorized)
    expect(SpreeUberDirect::WebhookEvent.find_by(delivery_id: 'del_1')).to be_nil
  end

  it 'rejects a request with no signature header at all' do
    post path, params: body, headers: { 'CONTENT_TYPE' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects every request when no credential is connected for the default store' do
    SpreeUberDirect::Credential.destroy_all

    post path, params: body, headers: headers

    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not enqueue a job twice for a duplicate delivery of the same event' do
    expect(SpreeUberDirect::DeliveryWebhookJob).to receive(:perform_later).once

    2.times { post path, params: body, headers: headers }

    expect(response).to have_http_status(:ok)
    expect(SpreeUberDirect::WebhookEvent.where(delivery_id: 'del_1', status: 'pickup').count).to eq(1)
  end

  it 'treats a redelivery with a genuinely different payload body as a distinct event, not a duplicate' do
    other_body = { delivery_id: 'del_1', status: 'pickup', courier_imminent: true }.to_json
    other_signature = OpenSSL::HMAC.hexdigest('SHA256', secret, other_body)

    expect(SpreeUberDirect::DeliveryWebhookJob).to receive(:perform_later).twice

    post path, params: body, headers: headers
    post path, params: other_body, headers: headers(signature: other_signature)

    expect(SpreeUberDirect::WebhookEvent.where(delivery_id: 'del_1', status: 'pickup').count).to eq(2)
  end

  it 'returns 400 for a body that is not valid JSON' do
    bad_body = '{not json'
    post path, params: bad_body, headers: headers(signature: OpenSSL::HMAC.hexdigest('SHA256', secret, bad_body))

    expect(response).to have_http_status(:bad_request)
  end
end
