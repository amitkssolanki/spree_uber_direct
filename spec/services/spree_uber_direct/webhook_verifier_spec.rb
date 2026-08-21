RSpec.describe SpreeUberDirect::WebhookVerifier do
  let(:secret) { 'test-webhook-signing-secret' }
  let(:body) { '{"delivery_id":"del_1","status":"pickup"}' }
  let(:valid_signature) { OpenSSL::HMAC.hexdigest('SHA256', secret, body) }

  describe '.valid?' do
    it 'is true when the x-uber-signature header is a correct HMAC-SHA256 of the raw body' do
      expect(
        described_class.valid?(signature_header: valid_signature, raw_body: body, signing_secret: secret)
      ).to be true
    end

    it 'is false when the signature does not match' do
      expect(
        described_class.valid?(signature_header: 'a' * 64, raw_body: body, signing_secret: secret)
      ).to be false
    end

    it 'is false when the body was tampered with after signing' do
      expect(
        described_class.valid?(signature_header: valid_signature, raw_body: body + 'tampered', signing_secret: secret)
      ).to be false
    end

    it 'is false when the header is missing' do
      expect(
        described_class.valid?(signature_header: nil, raw_body: body, signing_secret: secret)
      ).to be false
    end

    it 'is false when there is no configured signing secret to compare against' do
      expect(
        described_class.valid?(signature_header: valid_signature, raw_body: body, signing_secret: nil)
      ).to be false
    end
  end
end
