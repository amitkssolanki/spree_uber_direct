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

  it 'acknowledges but drops a real courier_update payload (no status field) instead of erroring' do
    # Real payload shape confirmed live: courier location pings carry
    # `kind: "event.courier_update"` and a `data` object, but no top-level
    # `status` at all — before this fix, WebhookEvent's presence
    # validation on `status` turned this into an unhandled 404.
    courier_update_body = {
      id: 'evt_courier_ping', kind: 'event.courier_update',
      data: { batch_id: 'bat_1', complete: false, courier: { name: 'Alex H.' } }
    }.to_json
    signature = OpenSSL::HMAC.hexdigest('SHA256', secret, courier_update_body)

    expect(SpreeUberDirect::DeliveryWebhookJob).not_to receive(:perform_later)

    post path, params: courier_update_body, headers: headers(signature: signature)

    expect(response).to have_http_status(:ok)
    expect(SpreeUberDirect::WebhookEvent.count).to eq(0)
  end

  it 'persists a real refund_request payload instead of silently dropping it' do
    # Payload shape confirmed against Uber's own webhook docs: a refund
    # notification carries `kind: "event.refund_request"` and a `data`
    # object full of refund-specific fields (refund_fees,
    # refund_order_items, total_partner_refund, ...) — no top-level
    # `status` field, same gap as courier_update, but unlike a courier
    # ping this data is real and can't be recovered later, so it gets its
    # own persistence path instead of falling into the generic
    # blank-status drop.
    refund_request_body = {
      id: 'evt_refund_1', kind: 'event.refund_request', delivery_id: 'del_1',
      data: {
        id: 'refund_1', currency_code: 'usd', total_partner_refund: 500, total_uber_refund: 0,
        refund_fees: [{ type: 'partner', amount: 100 }],
        refund_order_items: [{ id: 'item_1', quantity: 1 }]
      }
    }.to_json
    signature = OpenSSL::HMAC.hexdigest('SHA256', secret, refund_request_body)

    expect(SpreeUberDirect::DeliveryWebhookJob).not_to receive(:perform_later)

    post path, params: refund_request_body, headers: headers(signature: signature)

    expect(response).to have_http_status(:ok)
    expect(SpreeUberDirect::WebhookEvent.count).to eq(0)

    refund_event = SpreeUberDirect::RefundEvent.find_by(delivery_id: 'del_1')
    expect(refund_event).to be_present
    expect(refund_event.payload['kind']).to eq('event.refund_request')
    expect(refund_event.payload.dig('data', 'total_partner_refund')).to eq(500)
    expect(refund_event.payload.dig('data', 'refund_fees')).to eq([{ 'type' => 'partner', 'amount' => 100 }])
  end

  it 'acknowledges a refund_request payload with no delivery_id instead of erroring' do
    # RefundEvent requires delivery_id, same as WebhookEvent requires
    # status — a payload that can't be persisted at all still has to be
    # acked rather than surfaced as a 4xx/5xx, or Uber's webhook delivery
    # system will just keep resending the identical, still-unpersistable
    # payload.
    refund_request_body = {
      id: 'evt_refund_2', kind: 'event.refund_request', data: { id: 'refund_2' }
    }.to_json
    signature = OpenSSL::HMAC.hexdigest('SHA256', secret, refund_request_body)

    post path, params: refund_request_body, headers: headers(signature: signature)

    expect(response).to have_http_status(:ok)
    expect(SpreeUberDirect::RefundEvent.count).to eq(0)
  end

  it 'does not persist a duplicate row for a retried refund_request delivery' do
    refund_request_body = {
      id: 'evt_refund_3', kind: 'event.refund_request', delivery_id: 'del_2',
      data: { id: 'refund_3', currency_code: 'usd', total_partner_refund: 250, total_uber_refund: 0 }
    }.to_json
    signature = OpenSSL::HMAC.hexdigest('SHA256', secret, refund_request_body)

    2.times { post path, params: refund_request_body, headers: headers(signature: signature) }

    expect(response).to have_http_status(:ok)
    expect(SpreeUberDirect::RefundEvent.where(delivery_id: 'del_2').count).to eq(1)
  end
end
