RSpec.describe SpreeUberDirect::DeliveryMapping do
  describe 'validations' do
    it 'is valid with an order' do
      expect(build(:uber_direct_delivery_mapping)).to be_valid
    end

    it 'requires an order' do
      expect(build(:uber_direct_delivery_mapping, order: nil)).not_to be_valid
    end

    it 'is unique per order' do
      order = create(:order)
      create(:uber_direct_delivery_mapping, order: order)
      dup = build(:uber_direct_delivery_mapping, order: order)
      expect(dup).not_to be_valid
    end

    it 'allows a nil external_delivery_id (a dispatch can fail before Uber ever returns one)' do
      order = create(:order)
      mapping = build(:uber_direct_delivery_mapping, order: order, external_delivery_id: nil)
      expect(mapping).to be_valid
    end

    it 'allows two failed-before-dispatch rows to both have a nil external_delivery_id' do
      create(:uber_direct_delivery_mapping, external_delivery_id: nil)
      dup = build(:uber_direct_delivery_mapping, external_delivery_id: nil)
      expect(dup).to be_valid
    end

    it 'requires a unique external_delivery_id when present' do
      existing = create(:uber_direct_delivery_mapping)
      dup = build(:uber_direct_delivery_mapping, external_delivery_id: existing.external_delivery_id)
      expect(dup).not_to be_valid
    end
  end

  describe '#mark_failed!' do
    it 'records a truncated error message' do
      mapping = create(:uber_direct_delivery_mapping)
      mapping.mark_failed!(StandardError.new('boom'))
      expect(mapping.reload.dispatch_error).to eq('boom')
    end
  end
end
