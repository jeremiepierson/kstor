# frozen_string_literal: true

require 'kstor/log'
require 'kstor/systemd'

require 'socket'
require 'timeout'

module KStor
  # Serve clients on UNIX sockets.
  class SocketServer
    GRACEFUL_TIMEOUT = 10

    def initialize(socket_path:, nworkers:)
      @path = socket_path
      @nworkers = nworkers
      @client_queue = Queue.new
      @workers = []
    end

    def start
      start_workers
      server = Systemd.socket || UNIXServer.new(@path)
      Systemd.service_ready
      loop { @client_queue.enq(server.accept.first) }
    rescue Interrupt
      Log.debug('socket_server: stopping.')
      stop(server)
      File.unlink(@path) if File.file?(@path)
      Log.info('socket_server: stopped.')
    end

    def work(client)
      # Abstract method.
      client.close
    end

    private

    def worker_run
      while (client = @client_queue.deq)
        Log.debug("socket_server: #{Thread.current.name} serving one client")
        work(client)
        Log.debug("socket_server: #{Thread.current.name} done serving client")
      end
    end

    def stop(server)
      Systemd.service_stopping
      Log.debug('socket_server: stopping UNIXServer')
      server.close
      Log.debug('socket_server: closing client queue')
      @client_queue.close
      Log.debug("socket_server: waiting #{GRACEFUL_TIMEOUT} seconds" \
                ' for workers to finish')
      Timeout.timeout(GRACEFUL_TIMEOUT) { @workers.each(&:join) }
    rescue Timeout::Error
      immediate_stop(server)
    end

    def immediate_stop
      Log.warn('socket_server: graceful timeout reached, killing workers')
      @workers.each { |w| w.raise(Interrupt.new('abort')) }
      @workers.each(&:join)
    end

    def start_workers
      @nworkers.times do |i|
        name = "worker-#{i}"
        @workers << Thread.new { worker_run }
        @workers.last.name = name
        Log.debug("socket_server: started #{name}")
      end
    end
  end
end
