class CreateSpreeUberDirectCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_uber_direct_credentials do |t|
      t.references :store, null: false, foreign_key: { to_table: :spree_stores }, index: { unique: true }

      # OAuth2 client_credentials — unlike spree_doordash's static
      # developer_id/key_id/signing_secret (which sign a fresh JWT
      # per-request, nothing to cache), Uber Direct issues an access token
      # from these that genuinely outlives a single request. All three
      # encrypted at the application layer regardless (see
      # SpreeUberDirect::Credential), matching every credential this
      # project stores.
      t.text :client_id
      t.text :client_secret
      t.text :customer_id

      # Cached OAuth access token + its real expiry, so SpreeUberDirect::Client
      # doesn't fetch a fresh token on every call the way DoorDash's
      # per-request JWT signing does — this is the one genuinely different
      # piece from spree_doordash's Credential. access_token is encrypted;
      # access_token_expires_at is a plain timestamp (not secret, needed for
      # a cheap needs_refresh? comparison).
      t.text :access_token
      t.datetime :access_token_expires_at

      # The dedicated webhook signing secret configured per-webhook in the
      # Direct dashboard (Edit → signing key) — verifies the x-uber-signature
      # header via HMAC-SHA256. Not the same value as client_secret.
      t.text :webhook_signing_secret

      t.string :uber_environment, null: false, default: 'sandbox'

      t.timestamps
    end
  end
end
