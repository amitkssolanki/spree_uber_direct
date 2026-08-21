require 'faraday'

module SpreeUberDirect
  # Thin wrapper around the Uber Direct API (`api.uber.com/v1/customers/
  # {customer_id}/...`). All Direct API access in this extension goes
  # through here.
  #
  # Auth is fundamentally different from SpreeDoordash::Client: Uber Direct
  # uses OAuth2 client_credentials (`auth.uber.com/oauth/v2/token`), which
  # issues a genuine bearer token that outlives a single request — unlike
  # DoorDash's per-request-signed 5-minute JWT, there's a real token to
  # cache and refresh here. The cache lives on the Credential row itself
  # (see SpreeUberDirect::Credential#needs_refresh?) rather than
  # Rails.cache — no extra infrastructure, and naturally picks up a
  # rotated client_secret on the very next call since a fresh
  # `Credential.find_by` is re-resolved per client instance (not memoized —
  # same rationale as SpreeSquare::Client and SpreeDoordash::Client: an
  # admin can edit the credential mid-process).
  class Client
    class MissingCredentialsError < StandardError; end

    SANDBOX_BASE_URL = 'https://api.uber.com'.freeze
    AUTH_URL = 'https://auth.uber.com/oauth/v2/token'.freeze
    SCOPE = 'eats.deliveries'.freeze

    def self.instance
      for_store
    end

    def self.for_store(store = Spree::Store.default)
      new(credential: SpreeUberDirect::Credential.find_by(store: store))
    end

    def initialize(credential: nil)
      @credential = credential
      raise MissingCredentialsError, 'No Uber Direct credential connected and UBER_DIRECT_CLIENT_ID is not set' if client_id.blank?
    end

    def sandbox?
      @credential ? @credential.sandbox? : ENV.fetch('UBER_DIRECT_ENVIRONMENT', 'sandbox') == 'sandbox'
    end

    # Create Quote — validates coverage/pricing before formally creating a
    # delivery, same "quote first" recommended flow as DoorDash's Drive API.
    def create_quote(payload)
      request(:post, "/v1/customers/#{customer_id}/delivery_quotes", payload)
    end

    # Create Delivery — formally dispatches from a still-open quote_id.
    def create_delivery(payload)
      request(:post, "/v1/customers/#{customer_id}/deliveries", payload)
    end

    def get_delivery(delivery_id)
      request(:get, "/v1/customers/#{customer_id}/deliveries/#{delivery_id}")
    end

    def cancel_delivery(delivery_id)
      request(:post, "/v1/customers/#{customer_id}/deliveries/#{delivery_id}/cancel")
    end

    private

    def request(method, path, body = nil)
      response = connection.send(method) do |req|
        req.url path
        req.headers['Authorization'] = "Bearer #{access_token}"
        req.headers['Content-Type'] = 'application/json'
        req.body = body.to_json if body
      end
      handle_response(response)
    end

    def connection
      @connection ||= Faraday.new(url: SANDBOX_BASE_URL)
    end

    def handle_response(response)
      parsed = response.body.present? ? JSON.parse(response.body) : {}
      return parsed if response.status.between?(200, 299)

      raise RequestError.new("Uber Direct API error (#{response.status}): #{parsed.inspect}", status: response.status, body: parsed)
    end

    def customer_id
      fetch_secret(:customer_id, env_key: 'UBER_DIRECT_CUSTOMER_ID')
    end

    def client_id
      fetch_secret(:client_id, env_key: 'UBER_DIRECT_CLIENT_ID')
    end

    def client_secret
      fetch_secret(:client_secret, env_key: 'UBER_DIRECT_CLIENT_SECRET')
    end

    # Credential first, ENV fallback second — same dual-path convention
    # SpreeSquare::Client's own `fetch` uses, kept for the same reason: a
    # one-off admin/dev rake task (mirroring spree_square's
    # `setup_demo_tax`) can run against a broader sandbox credential
    # without needing a Credential row set up first.
    def fetch_secret(key, env_key:)
      (@credential && @credential.public_send(key).presence) || ENV[env_key].presence
    end

    def access_token
      return fetch_token!['access_token'] unless @credential

      refresh_if_needed!
      @credential.access_token
    end

    def refresh_if_needed!
      return unless @credential.needs_refresh?

      token_data = fetch_token!
      @credential.update!(
        access_token: token_data['access_token'],
        access_token_expires_at: token_data['expires_in'].to_i.seconds.from_now
      )
    end

    # No caching on the credential-less (ENV-only) path — deliberately
    # simple: that path only exists for occasional ad-hoc scripting, not a
    # hot request path, so re-fetching a token every call costs nothing
    # worth optimizing for.
    def fetch_token!
      response = Faraday.post(AUTH_URL) do |req|
        req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req.body = URI.encode_www_form(
          client_id: client_id,
          client_secret: client_secret,
          grant_type: 'client_credentials',
          scope: SCOPE
        )
      end
      parsed = JSON.parse(response.body)
      unless response.status.between?(200, 299)
        raise RequestError.new("Uber Direct OAuth error (#{response.status}): #{parsed.inspect}", status: response.status, body: parsed)
      end

      parsed
    end
  end

  class RequestError < StandardError
    attr_reader :status, :body

    def initialize(message, status:, body:)
      super(message)
      @status = status
      @body = body
    end
  end
end
