module SpreeUberDirect
  # Receives Uber Direct webhook notifications. HMAC-verified (see
  # SpreeUberDirect::WebhookVerifier) rather than DoorDash's Basic-Auth
  # string-echo. Does the least possible work synchronously: verify,
  # record, ack, hand off to a job — same shape as every sibling
  # WebhooksController in this codebase.
  class WebhooksController < ActionController::Base
    # Explicit, not just `skip_before_action :verify_authenticity_token` —
    # this controller doesn't inherit the host app's ApplicationController,
    # so a static analyzer (Brakeman) correctly flags it as never actually
    # configured either way — same precedent as spree_doordash's and
    # spree_square's own WebhooksController.
    protect_from_forgery with: :null_session

    def create
      credential = SpreeUberDirect::Credential.find_by(store: Spree::Store.default)
      raw_body = request.raw_post

      unless SpreeUberDirect::WebhookVerifier.valid?(
        signature_header: request.headers['x-uber-signature'],
        raw_body: raw_body,
        signing_secret: credential&.webhook_signing_secret
      )
        Rails.logger.warn('[SpreeUberDirect] webhook signature verification failed')
        return head :unauthorized
      end

      payload = JSON.parse(raw_body)

      # Uber's dashboard lets a webhook subscribe to three event kinds on
      # this one endpoint: `event.delivery_status` (the only one with a
      # `status` field — confirmed live), `event.courier_update` (a
      # courier GPS ping fired every 20s once a courier is assigned — no
      # `status` field, confirmed live), and `event.refund_request` (fired
      # when a refund is requested — no `status` field either, confirmed
      # directly against Uber's own webhook payload docs). WebhookEvent's
      # `status` column is specifically Uber's *delivery* status (see its
      # own model comment) and requires presence, so acknowledge and drop
      # anything that doesn't carry one rather than letting it fail
      # validation and surface as a 404 to Uber's webhook delivery system
      # — a courier-location ping and a refund notification both need no
      # processing from this extension today.
      if payload['status'].blank?
        Rails.logger.debug { "[SpreeUberDirect] dropping webhook with no status (kind=#{payload['kind']}, id=#{payload['id']})" }
        return head :ok
      end

      event = find_or_log_event(raw_body, payload)
      SpreeUberDirect::DeliveryWebhookJob.perform_later(event.id) if event.previously_new_record?

      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def find_or_log_event(raw_body, payload)
      SpreeUberDirect::WebhookEvent.find_or_create_by!(
        delivery_id: payload['delivery_id'],
        status: payload['status'],
        payload_digest: SpreeUberDirect::WebhookEvent.digest(raw_body)
      ) do |event|
        event.payload = payload
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # Lost a race with a concurrent duplicate delivery — the row exists
      # now either way, and it's already being (or has been) processed once.
      SpreeUberDirect::WebhookEvent.find_by!(
        delivery_id: payload['delivery_id'],
        status: payload['status'],
        payload_digest: SpreeUberDirect::WebhookEvent.digest(raw_body)
      )
    end
  end
end
