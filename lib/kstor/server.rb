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
    def initialize(controller:, **args)
      @controller = controller
      super(**args)
    end

    def work(client)
      client_data, = client.recvfrom(4096)
      Log.debug("server: read #{client_data.bytesize} bytes from client")
      server_data = handle_client_data(client_data)
      Log.debug("server: sending #{server_data.bytesize} bytes of response" \
                ' to client')
      client.send(server_data, 0)
      client.close
    end

    private

    def handle_client_data(data)
      req = Request.parse(data)
      resp = @controller.handle_request(req)
      resp.serialize
    rescue JSON::ParserError => e
      err = Error.for_code('MSG/INVALID', e.message)
      Log.info('server: ' + err.to_s)
      err.response.serialize
    end
  end
end
