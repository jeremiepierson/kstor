# frozen_string_literal: true

require 'kstor/socket_server'
require 'kstor/controller'
require 'kstor/message'
require 'kstor/log'
require 'kstor/error'

module KStor
  # Error: invalid request.
  class InvalidMessage < Error
    error_code 'MSG/INVALID'
    error_message 'JSON error: %s'
  end

  # Listen for clients and respond to their requests.
  class Server < SocketServer
    # Create a new server object.
    #
    # @param controller [KStor::Controller::RequestHandler] client request
    #   handler
    # @param args [Hash] parameters to apss to parent class
    #   {KStor::SocketServer}
    # @return [KStor::Server] new KStor server.
    def initialize(controller:, **args)
      @controller = controller
      super(**args)
    end

    # Implement {KStor::SocketServer#work} to actually serve clients.
    #
    # This method must read client request, write a response and close the
    # socket.
    #
    # @param client [Socket] channel of communication to a client
    def work(client)
      client_data, = client.recvfrom(4096)
      Log.debug("server: read #{client_data.bytesize} bytes from client")
      server_data = handle_client_data(client_data)
      Log.debug("server: sending #{server_data.bytesize} bytes of response " \
                'to client')
      client.send(server_data, 0)
    rescue Errno::EPIPE
      Log.info('server: client unexpectedly broke connection')
    ensure
      client.close
    end

    private

    def handle_client_data(data)
      req = Message.parse_request(data)
      resp = @controller.handle_request(req)
      Log.debug("server: response = #{resp.inspect}")
      resp.serialize
    rescue JSON::ParserError => e
      err = Error.for_code('MSG/INVALID', e.message)
      Log.info("server: #{err}")
      err.response.serialize
    rescue RequestMissesAuthData
      raise Error.for_code('MSG/INVALID', 'Missing authentication data')
    end
  end
end
