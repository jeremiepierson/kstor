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
      server = Systemd.socket
      Systemd.service_ready
      loop do
        maintain_workers
        @client_queue.enq(server.accept.first)
      end
    rescue Interrupt
      stop(server)
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
      Log.debug('socket_server: closing UNIXServer')
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
        @workers << start_worker("worker-#{i}")
        Log.debug("socket_server: started #{@workers.last.name}")
      end
    end

    def start_worker(name)
      thr = Thread.new { worker_run }
      thr.name = name

      thr
    end

    def maintain_workers
      collect_dead_workers.each do |i, w|
        name = w.name
        Log.error("socket_server: #{name} died!")
        rescue_worker_exception(w)
        Log.info("socket_server: performing resurrection on #{name}")
        @workers[i] = start_worker(name)
        Log.debug("socket_server: welcome back, comrade #{name}")
      end
    end

    def collect_dead_workers
      deads = {}
      @workers.each_with_index do |w, i|
        next if %w[sleep run].include?(w.status)

        Log.debug("socket_server: #{w.name} status is #{w.status.inspect}")
        deads[i] = w
      end

      deads
    end

    # rubocop:disable Lint/RescueException
    def rescue_worker_exception(worker)
      worker.join
    rescue Exception => e
      Log.exception(e)
    end
    # rubocop:enable Lint/RescueException
  end
end
