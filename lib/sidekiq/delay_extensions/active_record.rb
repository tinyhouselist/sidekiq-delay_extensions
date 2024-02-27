# frozen_string_literal: true

require "sidekiq/delay_extensions/generic_proxy"

module Sidekiq
  module DelayExtensions
    ##
    # Adds +delay+, +delay_for+ and +delay_until+ methods to ActiveRecord to offload instance method
    # execution to Sidekiq.
    #
    # @example
    #   User.recent_signups.each { |user| user.delay.mark_as_awesome }
    #
    # Please note, this is not recommended as this will serialize the entire
    # object to Redis.  Your Sidekiq jobs should pass IDs, not entire instances.
    # This is here for backwards compatibility with Delayed::Job only.
    class DelayedModel < GenericJob
    end

    module ActiveRecord
      def sidekiq_delay_proxy
        if Sidekiq::DelayExtensions.use_generic_proxy
          GenericProxy
        else
          Proxy
        end
      end

      def sidekiq_delay(options = {})
        sidekiq_delay_proxy.new(DelayedModel, self, options)
      end

      def sidekiq_delay_for(interval, options = {})
        sidekiq_delay_proxy.new(DelayedModel, self, options.merge("at" => Time.now.to_f + interval.to_f))
      end

      def sidekiq_delay_until(timestamp, options = {})
        sidekiq_delay_proxy.new(DelayedModel, self, options.merge("at" => timestamp.to_f))
      end
      alias_method :delay, :sidekiq_delay
      alias_method :delay_for, :sidekiq_delay_for
      alias_method :delay_until, :sidekiq_delay_until
    end
  end
end
