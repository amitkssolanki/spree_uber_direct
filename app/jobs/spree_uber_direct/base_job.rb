module SpreeUberDirect
  class BaseJob < Spree::BaseJob
    queue_as SpreeUberDirect.queue
  end
end
