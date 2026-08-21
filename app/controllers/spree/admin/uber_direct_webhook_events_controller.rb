module Spree
  module Admin
    # Read-only support/diagnostic view — same shape as UberDirectDeliveryMappingsController.
    class UberDirectWebhookEventsController < ResourceController
      def model_class
        SpreeUberDirect::WebhookEvent
      end
    end
  end
end
