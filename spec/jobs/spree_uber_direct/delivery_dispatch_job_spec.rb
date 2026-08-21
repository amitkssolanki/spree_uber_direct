RSpec.describe SpreeUberDirect::DeliveryDispatchJob do
  describe '#perform' do
    it 'calls the dispatcher for the order' do
      order = create(:order)

      expect(SpreeUberDirect::DeliveryDispatcher).to receive(:call).with(order)

      described_class.perform_now(order.id)
    end
  end

  describe 'when retries are exhausted' do
    it "marks the order's DeliveryMapping failed and alerts, and does not let the error escape" do
      order = create(:order)
      allow(SpreeUberDirect::DeliveryDispatcher).to receive(:call).and_raise(StandardError, 'boom')
      expect(SpreeUberDirect::Alerting).to receive(:capture).with(
        instance_of(StandardError), context: { area: 'delivery_dispatch', order_number: order.number }
      )

      job = described_class.new(order.id)
      job.exception_executions = { '[StandardError]' => 4 }

      expect { job.perform_now }.not_to raise_error

      mapping = SpreeUberDirect::DeliveryMapping.find_by(order: order)
      expect(mapping.dispatch_error).to include('boom')
    end
  end
end
