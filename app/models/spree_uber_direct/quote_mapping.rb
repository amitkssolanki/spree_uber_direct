module SpreeUberDirect
  # Tracks the most recent Uber Direct quote requested for an order,
  # generated as checkout progresses (see Spree::Calculator::Shipping::
  # UberDirectQuote, M3) and consulted again at order.completed to decide
  # whether to accept it as-is or re-quote (see DeliveryDispatcher, M4) —
  # same role as SpreeDoordash::QuoteMapping, checkout can easily outlast a
  # quote's validity window.
  #
  # Unlike DoorDash's 5-minute rule (undocumented on the response itself,
  # just DoorDash's own stated policy), `expired?` here checks Uber's own
  # returned `quote_expires_at` — always accurate to what Uber will
  # actually honor, never a guessed/hardcoded window.
  class QuoteMapping < Spree.base_class
    self.table_name = 'spree_uber_direct_quote_mappings'

    belongs_to :order, class_name: 'Spree::Order'

    validates :order, presence: true, uniqueness: true
    validates :external_quote_id, presence: true, uniqueness: true

    def expired?
      quote_expires_at.blank? || quote_expires_at <= Time.current
    end
  end
end
