module SpreeUberDirect
  # A Direct account's OAuth client_credentials + Customer ID for one
  # Spree::Store, plus a cached access token. Unlike SpreeDoordash::Credential
  # (a static access key that signs a fresh short-lived JWT per call, nothing
  # to cache), Uber Direct's OAuth2 client_credentials grant issues a genuine
  # bearer token that outlives a single request — SpreeUberDirect::Client
  # caches it here and refreshes it proactively before it actually expires,
  # rather than fetching a fresh one on every call.
  class Credential < Spree.base_class
    self.table_name = 'spree_uber_direct_credentials'

    belongs_to :store, class_name: 'Spree::Store'

    encrypts :client_id, :client_secret, :customer_id, :access_token, :webhook_signing_secret

    validates :store, presence: true, uniqueness: true
    validates :client_id, :client_secret, :customer_id, presence: true

    def sandbox?
      uber_environment == 'sandbox'
    end

    # A short margin before the token's real expiry, not right up against
    # it — avoids a request racing the token's actual expiration mid-flight.
    # Mirrors SpreeSquare::Credential's own needs_refresh? margin rationale.
    REFRESH_MARGIN = 60 # seconds

    def needs_refresh?
      access_token.blank? || access_token_expires_at.blank? ||
        access_token_expires_at <= REFRESH_MARGIN.seconds.from_now
    end
  end
end
