module SpreeUberDirect
  # One place for "this needs a human" — used when a job exhausts its
  # retries. A standalone copy of the same pattern SpreeSquare::Alerting
  # and SpreeDoordash::Alerting each already carry, not a dependency on
  # either sibling gem — spree_uber_direct stays independently installable
  # on its own.
  class Alerting
    def self.capture(error, context: {})
      context = { source: 'spree_uber_direct' }.merge(context.is_a?(String) ? { area: context } : context)

      Rails.logger.error("[SpreeUberDirect] #{context[:area] || 'error'}: #{error.class}: #{error.message}")

      return unless defined?(Sentry)

      Sentry.capture_exception(error, extra: context)
    end
  end
end
