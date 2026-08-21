module SpreeUberDirect
  # Bridges Spree::Calculator::Shipping::UberDirectQuote#compute_package's
  # uber_direct_quote_unavailable warning back onto the real order object —
  # same object-identity bridge and same rationale as spree_doordash's own
  # Spree::OrderDecorator (see that file's docstring for the full
  # root-cause story: package.order is a distinct in-memory object from
  # the order create_proposed_shipments holds, so a direct
  # `package.order.warnings |= [...]` silently mutates a throwaway copy).
  #
  # Deliberately namespaced `SpreeUberDirect::OrderDecorator`, NOT the bare
  # `Spree::OrderDecorator` spree_doordash already defines — both gems
  # prepend a module onto Spree::Order, and reusing the *same* module name
  # would reopen spree_doordash's module and silently overwrite its method
  # instead of creating a second link in Order's prepend chain. Distinct
  # module objects chain correctly via `super`; this is why `super` is
  # called here even though it looks like it "does nothing" locally — it's
  # what lets spree_doordash's own create_proposed_shipments override
  # still run too, regardless of which gem's initializer loads its
  # decorator first.
  module OrderDecorator
    def create_proposed_shipments
      Spree::Calculator::Shipping::UberDirectQuote.clear_unavailable(id)
      result = super
      merge_uber_direct_quote_warning!
      result
    end

    private

    def merge_uber_direct_quote_warning!
      return unless Spree::Calculator::Shipping::UberDirectQuote.unavailable?(id)

      Spree::Calculator::Shipping::UberDirectQuote.clear_unavailable(id)
      self.warnings |= [{
        code: 'uber_direct_quote_unavailable',
        message: 'We could not get an Uber Direct delivery quote for this address.'
      }]
    end
  end

  Spree::Order.prepend OrderDecorator
end
