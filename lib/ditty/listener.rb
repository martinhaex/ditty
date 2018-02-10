# frozen_string_literal: true

require 'wisper'

module Ditty
  class Listener
    def initialize
      @mutex = Mutex.new
    end

    def log_action(method, *args)
      vals = { action: method }
      return unless args[0].is_a? Hash
      vals[:user] = args[0][:user] if args[0] && args[0].key?(:user)
      vals[:details] = args[0][:details] if args[0] && args[0].key?(:details)
      @mutex.synchronize { Ditty::AuditLog.create vals }
    end

    def respond_to_missing?(_method, _include_private = false)
      # Respond to all tracking events
      true
    end
  end
end

Wisper.subscribe(Ditty::Listener.new) unless ENV['RACK_ENV'] == 'test'
