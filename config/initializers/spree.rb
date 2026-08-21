# Registers this extension's event subscriber with Spree's event system.
#
# Spree::Subscriber's own docstring says subscribers are "automatically
# registered during Rails initialization" — that's not what actually
# happens in spree_core 5.6.1: Spree::Events.register_subscribers! only
# ever iterates the explicit Spree.subscribers array. Without this file,
# SpreeUberDirect::OrderCompletedSubscriber is a real, loadable class (so
# specs calling it directly always pass) but is never actually wired to
# the 'order.completed' event in the running app — this exact gap was
# found live in spree_doordash before it carried this same fix. Mirrors
# spree_doordash's and spree_square's own identical registration.
Rails.application.config.after_initialize do
  Spree.subscribers << SpreeUberDirect::OrderCompletedSubscriber
end
