module SpreeUberDirect
  # Applies one already-verified, already-deduplicated Uber Direct webhook
  # event to the order it's mapped to. Same retry/dead-letter/Alerting
  # shape as every other webhook-handling job in this codebase.
  class DeliveryWebhookJob < BaseJob
    retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, error|
      SpreeUberDirect::WebhookEvent.find_by(id: job.arguments.first)&.mark_failed!(error)
      SpreeUberDirect::Alerting.capture(error, context: 'delivery_webhook')
    end

    def perform(webhook_event_id)
      event = SpreeUberDirect::WebhookEvent.find(webhook_event_id)
      SpreeUberDirect::DeliveryStatusMapper.call(event.payload)
      event.mark_processed!
    end
  end
end
