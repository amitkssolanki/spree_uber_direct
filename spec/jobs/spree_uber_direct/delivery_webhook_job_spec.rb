RSpec.describe SpreeUberDirect::DeliveryWebhookJob do
  describe '#perform' do
    it "maps the event's payload and marks the webhook event processed" do
      event = create(:uber_direct_webhook_event, delivery_id: 'del_1', status: 'pickup',
                                                   payload: { 'delivery_id' => 'del_1', 'status' => 'pickup' })

      expect(SpreeUberDirect::DeliveryStatusMapper).to receive(:call).with(event.payload)

      described_class.perform_now(event.id)

      expect(event.reload.processing_status).to eq('processed')
    end
  end

  describe 'when retries are exhausted' do
    it 'marks the webhook event failed and alerts, and does not let the error escape' do
      event = create(:uber_direct_webhook_event)
      allow(SpreeUberDirect::DeliveryStatusMapper).to receive(:call).and_raise(StandardError, 'boom')
      expect(SpreeUberDirect::Alerting).to receive(:capture).with(instance_of(StandardError), context: 'delivery_webhook')

      job = described_class.new(event.id)
      job.exception_executions = { '[StandardError]' => 4 }

      expect { job.perform_now }.not_to raise_error

      expect(event.reload.processing_status).to eq('failed')
    end
  end
end
