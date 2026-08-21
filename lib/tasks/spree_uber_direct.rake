namespace :spree_uber_direct do
  # M1 verification: proves the OAuth client_credentials flow actually
  # works against a real Sandbox account — fetches a real token from
  # auth.uber.com, then calls a real Direct endpoint with it. Uses
  # `credential: nil` to read UBER_DIRECT_CLIENT_ID/CLIENT_SECRET/CUSTOMER_ID
  # from ENV directly, same convenience path spree_square's demo rake tasks
  # use, rather than requiring a Credential row to exist first.
  desc 'Verify Uber Direct sandbox credentials: fetch a real OAuth token and call a real endpoint'
  task verify_connection: :environment do
    client = SpreeUberDirect::Client.new(credential: nil)
    puts "Environment: #{client.sandbox? ? 'sandbox' : 'production'}"

    # Delivery Quotes has no "list" endpoint — a deliberately-invalid quote
    # request (missing required fields) is the simplest real round trip
    # that proves both legs work: a real OAuth token was minted (a token
    # failure surfaces as a distinct 401 from auth.uber.com, not this),
    # and it was accepted by a real Direct endpoint (a 4xx validation
    # response — not a 401/403 — proves the token itself was valid).
    begin
      client.create_quote({})
      puts 'Unexpected: an empty quote request was accepted outright.'
    rescue SpreeUberDirect::RequestError => e
      if e.status == 401 || e.status == 403
        abort "Auth failed (#{e.status}): #{e.body.inspect} — check UBER_DIRECT_CLIENT_ID/CLIENT_SECRET/CUSTOMER_ID."
      else
        puts "OAuth token acquired and accepted. Endpoint responded #{e.status} (expected — the request body was intentionally incomplete): #{e.body.inspect}"
      end
    end
  end
end
