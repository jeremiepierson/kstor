# frozen_string_literal: true

require 'sd_notify'

module KStor
  # Collection of methods for systemd integration.
  module InitSystem
    class << self
      # Get main socket from systemd
      #
      # @return [nil,Socket] The socket or nil if systemd didn't provide
      def socket
        return nil unless systemd?

        listen_pid = ENV['LISTEN_PID'].to_i
        return nil unless Process.pid == listen_pid

        Socket.for_fd(3)
      end

      # Notify systemd that we're ready to serve clients.
      def service_ready
        SdNotify.ready if systemd?
      end

      # Notify systemd that we're stopping.
      def service_stopping
        SdNotify.stopping if systemd?
      end

      # True if KStor server was started by systemd.
      def systemd?
        return @systemd if @systemd

        parent = File.realpath("/proc/#{Process.ppid}/exe")
        @systemd = /systemd/.match?(parent)
        if @systemd
          Log.debug('init_system: systemd it is.')
        else
          Log.debug('init_system: systemd it is not.')
        end
        @systemd
      rescue Errno::ENOENT
        !!ENV['INIT_IS_SYSTEMD']
      end

      # Default path for main socket.
      def default_socket_path
        if systemd?
          '/run/kstor-server.socket'
        else
          '/var/run/kstor-server.socket'
        end
      end
    end
  end
end
