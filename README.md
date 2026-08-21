# SpreeUberDirect

Dispatches completed [Spree Commerce](https://spreecommerce.org) orders as [Uber Direct](https://developer.uber.com/docs/deliveries/overview)
deliveries — live delivery-fee quoting during checkout, dispatch on order completion, and delivery
status synced back via webhooks.

A second, independent delivery provider alongside [`spree_doordash`](https://github.com/amitkssolanki/spree_doordash)
— both extensions add their own `Spree::ShippingMethod`, so a store can offer either, both, or
neither, with zero coupling between them.

## Installation

Add to your Gemfile:

```ruby
gem 'spree_uber_direct', git: 'https://github.com/amitkssolanki/spree_uber_direct.git', tag: 'v0.1.0'
```

Then:

```bash
bundle install
bin/rails spree_uber_direct:install:migrations
bin/rails db:migrate
```

## Setup

1. Create a Direct account at [direct.uber.com](https://direct.uber.com) and log in with your Uber
   account. Sandbox credentials (Client ID, Client Secret, Customer ID) are available immediately
   under the Developer tab in Management — no approval needed for sandbox.
2. In your Spree admin, go to **Uber Direct Connection** and paste the three sandbox values.
3. Register a webhook endpoint in the Direct dashboard pointing at
   `https://your-store.example.com/spree_uber_direct/webhooks/uber_direct`, then copy its signing
   key into the same admin form.

Production access requires providing billing information and Uber's approval — see
[developer.uber.com/docs/deliveries/get-started](https://developer.uber.com/docs/deliveries/get-started).
No fixed timeline is published for that approval; sandbox has none of that restriction.

## Environment variables (alternative to the admin form, useful for scripting/rake tasks)

```
UBER_DIRECT_CLIENT_ID=
UBER_DIRECT_CLIENT_SECRET=
UBER_DIRECT_CUSTOMER_ID=
UBER_DIRECT_ENVIRONMENT=sandbox
```

## Testing

```bash
bundle install
bundle exec rake test_app
bundle exec rspec
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE.md](LICENSE.md).
