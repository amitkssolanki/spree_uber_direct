# Changelog

All notable changes to this project are documented here.

## 0.1.0

Initial scaffold (M1 — Foundation): gemspec, engine, `Credential` model (OAuth2
client_credentials — client_id/client_secret/customer_id, cached access token with
expiry-aware refresh, webhook signing key), admin credential form, `Client` service.

**Verified against a real Uber Direct Sandbox account**, not just specs: a real access
token was fetched from `auth.uber.com/oauth/v2/token` via `client_credentials`, and
accepted by a real `POST /v1/customers/{customer_id}/delivery_quotes` call — the
endpoint returned a real `400 invalid_params` for the intentionally-incomplete test
payload (missing `pickup_address`/`dropoff_address`), not a `401`/`403`, confirming
both the OAuth leg and the API-call leg work end to end against production Uber
infrastructure (sandbox mode).
