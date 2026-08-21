module SpreeUberDirect
  # Verifies inbound Uber Direct webhooks. Architecturally different from
  # SpreeDoordash::WebhookVerifier's Basic-Auth string-echo scheme: Uber
  # Direct signs with a real HMAC — confirmed directly against
  # developer.uber.com's webhook guide, not assumed: the `x-uber-signature`
  # header is a lowercase-hex HMAC-SHA256 of the raw request body, keyed by
  # a dedicated webhook signing secret configured per-webhook in the Direct
  # dashboard (NOT the OAuth client_secret — a separate value entirely).
  class WebhookVerifier
    def self.valid?(signature_header:, raw_body:, signing_secret:)
      return false if signature_header.blank? || signing_secret.blank?

      expected = OpenSSL::HMAC.hexdigest('SHA256', signing_secret, raw_body.to_s)
      ActiveSupport::SecurityUtils.secure_compare(signature_header, expected)
    end
  end
end
