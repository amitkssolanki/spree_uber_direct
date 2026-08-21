# Changelog

All notable changes to this project are documented here.

## 0.1.0 (unreleased — in active local development)

A second, independent delivery provider alongside `spree_doordash` — same one-extension-per-integration
pattern already established by `spree_square`/`spree_doordash`/`spree_menu_chat`/`spree_loyalty`, offered
as a third shipping-method choice (Pickup, DoorDash Delivery, Uber Direct Delivery) rather than a
replacement for either.

**M1 — Foundation.** Gemspec, engine, `Credential` (OAuth2 `client_credentials` — client_id/client_secret/
customer_id, cached access token with expiry-aware refresh keyed off the credential's own `updated_at` so
a rotated secret takes effect immediately, webhook signing key), admin credential form, `Client` service
(token fetch/cache, `create_quote`/`create_delivery`/`get_delivery`/`cancel_delivery`). **Verified against
a real Uber Direct Sandbox account**: a real OAuth token was fetched from `auth.uber.com/oauth/v2/token`
and accepted by a real `POST /v1/customers/{customer_id}/delivery_quotes` call (real `400 invalid_params`
for an intentionally-incomplete payload, not `401`/`403`).

**M2 — Quoting.** `QuoteMapping` + `Quote` service. Simpler than DoorDash's own quote tracking in two ways
confirmed against Uber's real `openapi.yaml` (`github.com/uber/uber-direct-sdk`): the quote id is
server-generated and returned fresh on every call (no client-side id-collision risk DoorDash's own
`external_delivery_id` needed a random suffix to dodge), and Uber returns its own real `expires` timestamp
instead of a hardcoded documented window. Addresses are JSON-encoded strings
(`{"street_address":[...],"city":...}`), not DoorDash's flat comma-joined string — confirmed directly
against the schema, not guessed. **Verified live**: a New York dropoff correctly got a real
`400 address_undeliverable` (412mi from the Fairview Park, OH pickup, outside Uber's 10mi radius — a true
rejection, not a bug), and a real nearby Ohio address got a real accepted quote ($7.99, 15-minute expiry).

**M3 — Storefront quoting.** `Spree::Calculator::Shipping::UberDirectQuote` reuses the same
zero-registration `Spree::ShippingCalculator` subclass mechanism `DoordashQuote` already proved out, and
the same `Thread.current` object-identity bridge for pushing an unavailable-quote warning onto the real
order (`package.order` is a distinct in-memory object from what `create_proposed_shipments` holds — see
`spree_doordash`'s own 0.1.3 for the full root-cause story this reuses verbatim).
`SpreeUberDirect::OrderDecorator` does the merge-back half — deliberately namespaced (not the bare
`Spree::OrderDecorator` name `spree_doordash` already claims) so both gems' prepended modules chain
correctly via `super` instead of one silently overwriting the other. No storefront (Next.js) code changes
needed. **Verified live**: a real checkout showed all three shipping methods together — Pickup $0.00, Uber
Direct Delivery $7.99 (+ tax), DoorDash Delivery $9.75 (+ tax) — confirming both delivery providers coexist
without either's decorator clobbering the other.

**M4 — Dispatch + webhooks.** `DeliveryMapping` (Uber mints a genuinely separate `del_`-prefixed delivery
id on `POST /deliveries`, unlike DoorDash which reuses the accepted quote's own id for the delivery's whole
lifecycle), `WebhookEvent` (idempotency key is `delivery_id` + `status` + a payload digest — Uber's
webhooks carry one event kind, `event.delivery_status`, with no distinct event id, the same gap DoorDash's
own webhooks have; the DB column holding *our own* pending/processed/failed tracking is named
`processing_status`, not `status`, specifically to avoid colliding with Uber's own delivery status value
which is genuinely called `status` in their payload). `WebhookVerifier` is architecturally different from
DoorDash's Basic-Auth string echo: real HMAC-SHA256 over the raw body via `x-uber-signature`, keyed by a
dedicated webhook signing secret (confirmed against developer.uber.com's webhook guide — a separate value
from the OAuth `client_secret`). `DeliveryDispatcher`/`DeliveryStatusMapper`/`WebhooksController`/
`DeliveryWebhookJob`/`DeliveryDispatchJob`/`OrderCompletedSubscriber`/`Alerting` all mirror their DoorDash
counterparts' exact shapes, adapted to Uber's real status vocabulary (`pending`/`pickup`/`pickup_complete`/
`dropoff`/`delivered`/`canceled`/`returned`/`shopping_completed`). Critically included
`config/initializers/spree.rb` registering the subscriber with `Spree.subscribers` — without it the
subscriber is real and loadable (specs calling it directly always pass) but never actually wired to a real
`order.completed` event, the exact silent gap `spree_doordash`'s own CHANGELOG documents finding live.

A real bug found live during this milestone's own verification: `DeliveryDispatcher` initially sent only
`{quote_id: ...}` to `POST /deliveries` — a real Sandbox `400` (`invalid_params`: `pickup_name`/
`dropoff_name`/`manifest` required) proved Uber's `DeliveryReq` needs a full payload even with a `quote_id`
attached, unlike DoorDash's `accept_quote` (which only needs the id). Extracted address/phone formatting
into a shared `AddressPayload` module (used by both `Quote` and `DeliveryDispatcher`) rather than
duplicating it.

**M5 — Admin UI + real Sandbox end-to-end verification.** Read-only admin pages for `DeliveryMapping`/
`WebhookEvent` (four-file pattern, including the `new_resource: false` fix both `spree_square` and
`spree_doordash` had to learn the hard way on their first real Postgres run — repeated here from the start
via `Rails.application.config.after_initialize`, needed because a running dev process doesn't hot-reload a
newly-added initializer file the way autoloaded `app/` code does, confirmed live via a real
`NoMethodError: Table 'uber_direct_delivery_mappings' has not been registered` until the process was
restarted). Nav positions 77–78 (credential itself at 76 from M1).

**Verified against real Uber Direct Sandbox infrastructure end to end, not just specs** — the same
standard every prior integration in this project was held to:
- A real order dispatched a real delivery using Uber's **Robo Courier** test feature
  (`test_specifications.robo_courier_specification.mode: "auto"` — the Sandbox equivalent of DoorDash's own
  Delivery Simulator, confirmed via live research, not assumed).
- Polled the real delivery and watched it progress through Uber's actual lifecycle end to end: `pending` →
  `pickup` → `dropoff` → `delivered`, with a real assigned test courier ("Alex H.") and `complete: true`.
- Fed that real `delivered` payload through `DeliveryStatusMapper` and confirmed it correctly recorded
  `last_status`/`courier_name`/`courier_phone` from Uber's real response shape.
- Both new admin pages (`/admin/uber_direct_delivery_mappings`, `/admin/uber_direct_webhook_events`) and the
  credential page confirmed loading against real Postgres data — all three real dispatch attempts from this
  session (including the earlier payload-bug 400) visible in the table.
- **Not live-tested this milestone**: inbound webhook *receiving* (a live POST from Uber hitting a real
  registered endpoint) — no public tunnel/registered webhook URL was set up in this session. The
  controller's signature verification, idempotency, and job dispatch are covered by real HMAC-signed
  request specs instead; genuinely receiving a live webhook remains open for whenever a tunnel is set up.
- `shipment.ship!` itself was not re-exercised live in this specific run (the verification order was built
  directly via console rather than walked through Spree's full checkout state machine, so the shipment
  never reached `ready`) — covered instead by a passing unit spec using a `ready`-state shipment.

101 examples, 0 failures across the full suite. Not yet tagged, pushed to a remote, or released to
RubyGems — kept local-only per explicit instruction.

**M6 (spec coverage/docs) and M7 (go-live) not started** — M7 is gated entirely on Uber's own production
approval (billing info + their review, timeline unstated in their docs), a business/account action only
the project owner can take.
