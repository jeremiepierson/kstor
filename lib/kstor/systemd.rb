# frozen_string_literal: true

require 'sd_notify'

module KStor
  # Collection of methods for systemd integration.
  module Systemd
    class << self
      def socket
        listen_pid = ENV['LISTEN_PID'].to_i
        return nil unless Process.pid == listen_pid

        Socket.for_fd(3)
      end

      def service_ready
        SdNotify.ready
      end

      def service_stopping
        SdNotify.stopping
      end
    end
  end
end
