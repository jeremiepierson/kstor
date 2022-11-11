# frozen_string_literal: true

require 'sd_notify'

module KStor
  # Collection of methods for systemd integration.
  module Systemd
    class << self
      # Get main socket from systemd
      #
      # @return [nil,Socket] The socket or nil if systemd didn't provide
      def socket
        listen_pid = ENV['LISTEN_PID'].to_i
        return nil unless Process.pid == listen_pid

        Socket.for_fd(3)
      end

      # Notify systemd that we're ready to serve clients.
      def service_ready
        SdNotify.ready
      end

      # Notify systemd that we're stopping.
      def service_stopping
        SdNotify.stopping
      end
    end
  end
end
