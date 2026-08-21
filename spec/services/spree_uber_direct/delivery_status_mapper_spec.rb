RSpec.describe SpreeUberDirect::DeliveryStatusMapper do
  let(:order) { create(:order, state: 'complete', completed_at: Time.current) }
  let!(:shipment) { create(:shipment, order: order, state: 'ready') }
  let(:mapping) { create(:uber_direct_delivery_mapping, order: order, external_delivery_id: 'del_123') }

  def payload(status, extra = {})
    { 'delivery_id' => mapping.external_delivery_id, 'status' => status }.merge(extra)
  end

  describe '.call' do
    it 'is a safe no-op when no DeliveryMapping matches the delivery_id' do
      expect { described_class.call({ 'delivery_id' => 'unknown', 'status' => 'pickup' }) }
        .not_to raise_error
    end

    it 'ships every ready shipment on delivered' do
      described_class.call(payload('delivered'))

      expect(shipment.reload.state).to eq('shipped')
    end

    it 'cancels the order on canceled' do
      described_class.call(payload('canceled'))

      expect(order.reload.state).to eq('canceled')
    end

    it 'cancels the order on returned' do
      described_class.call(payload('returned'))

      expect(order.reload.state).to eq('canceled')
    end

    it 'does not cancel an already-canceled order again' do
      order.cancel!
      expect(order).to receive(:cancel!).never

      described_class.call(payload('canceled'))
    end

    %w[pending pickup pickup_complete dropoff shopping_completed].each do |status|
      it "does not transition shipment or order state on #{status} (label-only)" do
        described_class.call(payload(status))

        expect(shipment.reload.state).not_to eq('shipped')
        expect(order.reload.state).not_to eq('canceled')
      end
    end

    it 'always records last_status and courier details from the nested data payload' do
      described_class.call(payload('pickup', {
                                     'data' => {
                                       'tracking_url' => 'https://www.ubereats.com/orders/xyz',
                                       'courier' => { 'name' => 'Alex I.', 'phone_number' => '+16283337630' }
                                     }
                                   }))

      mapping.reload
      expect(mapping.last_status).to eq('pickup')
      expect(mapping.tracking_url).to eq('https://www.ubereats.com/orders/xyz')
      expect(mapping.courier_name).to eq('Alex I.')
      expect(mapping.courier_phone).to eq('+16283337630')
    end

    it 'keeps the previous tracking_url/courier fields when a later event omits them' do
      mapping.update!(tracking_url: 'https://www.ubereats.com/orders/xyz', courier_name: 'Alex I.')

      described_class.call(payload('dropoff'))

      mapping.reload
      expect(mapping.tracking_url).to eq('https://www.ubereats.com/orders/xyz')
      expect(mapping.courier_name).to eq('Alex I.')
    end
  end
end
