# encoding: UTF-8
lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'spree_uber_direct/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_uber_direct'
  s.version     = SpreeUberDirect::VERSION
  s.summary     = 'Spree Commerce Uber Direct Delivery Extension'
  s.description = 'Dispatches completed Spree orders as Uber Direct deliveries — live delivery-fee ' \
                   'quoting during checkout, dispatch on order completion, and delivery status synced ' \
                   'back via webhooks. A second, independent delivery provider alongside spree_doordash ' \
                   '— same shipping-method-based routing pattern, offered as an additional choice, not ' \
                   'a replacement.'
  s.required_ruby_version = '>= 3.2'

  s.author    = 'Amit Solanki'
  s.email     = 'amit@prayantr.com'
  s.homepage  = 'https://github.com/amitkssolanki/spree_uber_direct'
  s.license   = 'MIT'

  s.metadata = {
    'homepage_uri' => s.homepage,
    'source_code_uri' => s.homepage,
    'changelog_uri' => "#{s.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri' => "#{s.homepage}/issues"
  }

  s.files = `git ls-files -z`.split("\x0").reject do |f|
    f.start_with?('spec/') && !f.start_with?('spec/fixtures')
  end
  s.require_path = 'lib'
  s.requirements << 'none'

  spree_version = '>= 5.4.0.beta'
  s.add_dependency 'spree', spree_version
  s.add_dependency 'spree_admin', spree_version

  # No official Ruby SDK for Uber Direct (the real one, uber/uber-direct-sdk,
  # is JS/TS-only) — plain OAuth2 client_credentials + REST against
  # api.uber.com via Faraday, already a transitive dependency through Spree
  # itself. No jwt dependency needed here (unlike spree_doordash) — Uber
  # Direct auth is a cached bearer token, not a per-request signed JWT.
  s.add_dependency 'faraday'

  s.add_development_dependency 'spree_dev_tools'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'gem-release'
end
