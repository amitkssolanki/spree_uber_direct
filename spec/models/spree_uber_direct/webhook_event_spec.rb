RSpec.describe SpreeUberDirect::WebhookEvent do
  describe 'validations' do
    it 'is valid with delivery_id, status, and payload_digest' do
      expect(build(:uber_direct_webhook_event)).to be_valid
    end

    it 'requires delivery_id and status' do
      event = build(:uber_direct_webhook_event, delivery_id: nil, status: nil)
      expect(event).not_to be_valid
      expect(event.errors.attribute_names).to include(:delivery_id, :status)
    end

    it 'is unique on the (delivery_id, status, payload_digest) idempotency key' do
      create(:uber_direct_webhook_event, delivery_id: 'del_1', status: 'pickup', payload_digest: 'dig-1')
      dup = build(:uber_direct_webhook_event, delivery_id: 'del_1', status: 'pickup', payload_digest: 'dig-1')
      expect(dup).not_to be_valid
    end

    it 'allows the same delivery_id and status with a genuinely different payload_digest (a real redelivery with new fields)' do
      create(:uber_direct_webhook_event, delivery_id: 'del_1', status: 'pickup', payload_digest: 'dig-1')
      different = build(:uber_direct_webhook_event, delivery_id: 'del_1', status: 'pickup', payload_digest: 'dig-2')
      expect(different).to be_valid
    end
  end

  describe '.digest' do
    it 'is a stable SHA256 hex digest of the raw body' do
      expect(described_class.digest('{"a":1}')).to eq(Digest::SHA256.hexdigest('{"a":1}'))
    end
  end

  describe '#mark_processed! / #mark_failed!' do
    it 'marks processed with a timestamp' do
      event = create(:uber_direct_webhook_event)
      event.mark_processed!
      expect(event.reload.processing_status).to eq('processed')
      expect(event.processed_at).to be_present
    end

    it 'marks failed with a truncated error message' do
      event = create(:uber_direct_webhook_event)
      event.mark_failed!(StandardError.new('boom'))
      expect(event.reload.processing_status).to eq('failed')
      expect(event.error_message).to eq('boom')
    end
  end

  describe '.pending' do
    it 'scopes to pending processing_status' do
      pending_event = create(:uber_direct_webhook_event)
      processed_event = create(:uber_direct_webhook_event)
      processed_event.mark_processed!

      expect(described_class.pending).to contain_exactly(pending_event)
    end
  end
end
