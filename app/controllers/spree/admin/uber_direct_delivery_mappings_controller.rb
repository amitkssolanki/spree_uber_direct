module Spree
  module Admin
    # Read-only support/diagnostic view — no create/edit/destroy, this is
    # visibility into what spree_uber_direct has already done, not a place
    # to change it. See config/routes.rb (only: [:index]).
    class UberDirectDeliveryMappingsController < ResourceController
      def model_class
        SpreeUberDirect::DeliveryMapping
      end
    end
  end
end
