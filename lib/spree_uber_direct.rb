require 'spree'
require 'spree_uber_direct/engine'
require 'spree_uber_direct/version'
require 'spree_uber_direct/configuration'

module SpreeUberDirect
  mattr_accessor :queue

  def self.queue
    @@queue ||= Spree.queues.default
  end
end
