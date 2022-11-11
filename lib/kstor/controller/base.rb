# frozen_string_literal: true

module KStor
  # Various controllers that participate in serving client.
  module Controller
    # Common code for all controllers (except RequestHandler).
    #
    # @abstract
    class Base
      class << self
        attr_accessor :request_types
        attr_accessor :response_types

        # True if sub-controller handles these requests.
        #
        # @param type [String] request type
        # @return [Boolean] true if request type may be handled
        def handles?(type)
          @request_types.include?(type)
        end
      end

      # Create sub-controller with access to data store.
      #
      # @param store [KStor::Store] data store
      # @return [KStor::Controller::Base] a new sub-controller
      def initialize(store)
        @store = store
        @request_handlers = self.class.request_types.to_h do |type|
          meth = "handle_#{type}".to_sym
          [type, meth]
        end
      end

      # Handle client request.
      #
      # @param user [KStor::Model::User] user making this request
      # @param req [KStor::LoginRequest, KStor::SessionRequest] client request
      def handle_request(user, req)
        unless @request_handlers.key?(req.type)
          raise Error.for_code('REQ/UNKNOWN', req.type)
        end

        __send__(@request_handlers[req.type], user, req)
      end
    end
  end
end
