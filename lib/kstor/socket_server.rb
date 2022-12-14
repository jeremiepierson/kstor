# frozen_string_literal: true

require 'socket'
require 'timeout'
require 'fileutils'

require 'kstor/log'
require 'kstor/init_system'

module KStor
  # Serve clients on UNIX sockets.
  class SocketServer
    # Wait this number of seconds for worker threads to terminate before
    # killing them without mercy.
    GRACEFUL_TIMEOUT = 10

    # Create a new server.
    #
    # @param socket_path [String] path to listening socket
    # @param nworkers [Integer] number of worker threads
    def initialize(socket_path:, nworkers:)
      @path = socket_path
      @nworkers = nworkers
      @client_queue = Queue.new
      @workers = []
    end

    # Start serving clients.
    #
    # Send interrupt signal to cleanly stop.
    def start
      start_workers
      server = server_socket
      InitSystem.service_ready
      Log.info('socket_server: started')
      loop do
        maintain_workers
        @client_queue.enq(server.accept.first)
      end
    rescue Interrupt
      stop(server)
      FileUtils.rm(@path) unless InitSystem.systemd?
      Log.info('socket_server: stopped.')
    end

    # Do some work for a client and write a response.
    # @abstract
    def work(client)
      # Abstract method.
      client.close
    end

    private

    def server_socket
      s = InitSystem.socket
      return s if s

      UNIXServer.new(@path)
    rescue Errno::EACCES
      Log.fatal("Can't open socket at #{@path} (permission denied).")
      exit(1)
    rescue Errno::EADDRINUSE
      Log.fatal("Can't open socket at #{@path} (address already in use).")
      exit(1)
    end

    def worker_run
      while (client = @client_queue.deq)
        Log.debug("socket_server: #{Thread.current.name} serving one client")
        work(client)
        Log.debug("socket_server: #{Thread.current.name} done serving client")
      end
    end

    def stop(server)
      InitSystem.service_stopping
      Log.debug('socket_server: closing UNIXServer')
      server.close
      Log.debug('socket_server: closing client queue')
      @client_queue.close
      Log.debug("socket_server: waiting #{GRACEFUL_TIMEOUT} seconds " \
                'for workers to finish')
      Timeout.timeout(GRACEFUL_TIMEOUT) { @workers.each(&:join) }
    rescue Timeout::Error
      Log.warn('socket_server: graceful timeout reached, killing workers')
      immediate_stop(server)
    end

    def immediate_stop
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
