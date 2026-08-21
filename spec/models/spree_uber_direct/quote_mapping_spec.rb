RSpec.describe SpreeUberDirect::QuoteMapping do
  describe 'validations' do
    it 'is valid with an order and external_quote_id' do
      expect(build(:uber_direct_quote_mapping)).to be_valid
    end

    it 'requires an order' do
      expect(build(:uber_direct_quote_mapping, order: nil)).not_to be_valid
    end

    it 'is unique per order' do
      order = create(:order)
      create(:uber_direct_quote_mapping, order: order)
      dup = build(:uber_direct_quote_mapping, order: order)
      expect(dup).not_to be_valid
    end

    it 'requires a unique external_quote_id' do
      existing = create(:uber_direct_quote_mapping)
      dup = build(:uber_direct_quote_mapping, external_quote_id: existing.external_quote_id)
      expect(dup).not_to be_valid
    end
  end

  describe '#expired?' do
    it 'is true when quote_expires_at is blank' do
      expect(build(:uber_direct_quote_mapping, quote_expires_at: nil)).to be_expired
    end

    it 'is true when quote_expires_at is in the past' do
      expect(build(:uber_direct_quote_mapping, quote_expires_at: 1.minute.ago)).to be_expired
    end

    it 'is false when quote_expires_at is in the future' do
      expect(build(:uber_direct_quote_mapping, quote_expires_at: 15.minutes.from_now)).not_to be_expired
    end
  end
end
