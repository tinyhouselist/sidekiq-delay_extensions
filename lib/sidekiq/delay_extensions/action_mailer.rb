# frozen_string_literal: true

require "sidekiq/delay_extensions/generic_proxy"

module Sidekiq
  module DelayExtensions
    ##
    # Adds +delay+, +delay_for+ and +delay_until+ methods to ActionMailer to offload arbitrary email
    # delivery to Sidekiq.
    #
    # @example
    #    UserMailer.delay.send_welcome_email(new_user)
    #    UserMailer.delay_for(5.days).send_welcome_email(new_user)
    #    UserMailer.delay_until(5.days.from_now).send_welcome_email(new_user)
    class DelayedMailer < GenericJob
      def _perform(target, method_name, *args, **kwargs)
        msg =
          if kwargs.empty?
            target.public_send(method_name, *args)
          else
            target.public_send(method_name, *args, **kwargs)
          end
        # The email method can return nil, which causes ActionMailer to return
        # an undeliverable empty message.
        if msg
          msg.deliver_now
        else
          raise "#{target.name}##{method_name} returned an undeliverable mail object"
        end
      end
    end

    module ActionMailer
      def sidekiq_delay_proxy
        if Sidekiq::DelayExtensions.use_generic_proxy
          GenericProxy
        else
          Proxy
        end
      end

      def sidekiq_delay(options = {})
        sidekiq_delay_proxy.new(DelayedMailer, self, options)
      end

      def sidekiq_delay_for(interval, options = {})
        sidekiq_delay_proxy.new(DelayedMailer, self, options.merge("at" => Time.now.to_f + interval.to_f))
      end

      def sidekiq_delay_until(timestamp, options = {})
        sidekiq_delay_proxy.new(DelayedMailer, self, options.merge("at" => timestamp.to_f))
      end
      alias_method :delay, :sidekiq_delay
      alias_method :delay_for, :sidekiq_delay_for
      alias_method :delay_until, :sidekiq_delay_until
    end
  end
end
