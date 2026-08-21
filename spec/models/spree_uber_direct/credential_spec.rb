RSpec.describe SpreeUberDirect::Credential do
  describe 'validations' do
    it 'is valid with client_id, client_secret, customer_id, and a store' do
      expect(build(:uber_direct_credential)).to be_valid
    end

    it 'requires a store' do
      credential = build(:uber_direct_credential, store: nil)
      expect(credential).not_to be_valid
    end

    it 'requires client_id, client_secret, and customer_id' do
      credential = build(:uber_direct_credential, client_id: nil, client_secret: nil, customer_id: nil)
      expect(credential).not_to be_valid
      expect(credential.errors.attribute_names).to include(:client_id, :client_secret, :customer_id)
    end

    it 'is unique per store' do
      create(:uber_direct_credential, store: create(:store))
      dup = build(:uber_direct_credential, store: SpreeUberDirect::Credential.first.store)
      expect(dup).not_to be_valid
    end
  end

  describe '#sandbox?' do
    it 'is true for a sandbox-environment credential' do
      expect(build(:uber_direct_credential, uber_environment: 'sandbox')).to be_sandbox
    end

    it 'is false for a production-environment credential' do
      expect(build(:uber_direct_credential, uber_environment: 'production')).not_to be_sandbox
    end
  end

  describe '#needs_refresh?' do
    it 'is true when there is no cached token at all' do
      credential = build(:uber_direct_credential, access_token: nil, access_token_expires_at: nil)
      expect(credential).to be_needs_refresh
    end

    it 'is true when the cached token is already past its expiry' do
      credential = build(:uber_direct_credential, access_token: 'cached-token', access_token_expires_at: 1.minute.ago)
      expect(credential).to be_needs_refresh
    end

    it 'is true when the cached token expires within the refresh margin' do
      credential = build(:uber_direct_credential, access_token: 'cached-token', access_token_expires_at: 30.seconds.from_now)
      expect(credential).to be_needs_refresh
    end

    it 'is false when the cached token is comfortably valid' do
      credential = build(:uber_direct_credential, access_token: 'cached-token', access_token_expires_at: 1.hour.from_now)
      expect(credential).not_to be_needs_refresh
    end
  end

  describe 'encryption' do
    it 'encrypts client_id, client_secret, customer_id, access_token, and webhook_signing_secret at rest' do
      credential = create(:uber_direct_credential, client_secret: 'plain-client-secret')
      raw = ActiveRecord::Base.connection.select_value(
        "SELECT client_secret FROM spree_uber_direct_credentials WHERE id = #{credential.id}"
      )
      expect(raw).not_to eq('plain-client-secret')
      expect(credential.reload.client_secret).to eq('plain-client-secret')
    end
  end
end
