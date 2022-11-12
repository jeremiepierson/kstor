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

        # Declare that this controller handles this type of request.
        def request_type(klass)
          @request_types ||= []
          @request_types << klass
        end

        # Declare that this controller produces this type of response.
        def response_type(klass)
          @response_types ||= []
          @response_types << klass
        end

        # True if sub-controller handles these requests.
        #
        # @param type [String] request type
        # @return [Boolean] true if request type may be handled
        def handles?(req)
          @request_types.include?(req.class)
        end
      end

      # Create sub-controller with access to data store.
      #
      # @param store [KStor::Store] data store
      # @return [KStor::Controller::Base] a new sub-controller
      def initialize(store)
        @store = store
        @request_handlers = self.class.request_types.to_h do |klass|
          meth = "handle_#{klass.type}".to_sym
          [klass, meth]
        end
      end

      # Handle client request.
      #
      # @param user [KStor::Model::User] user making this request
      # @param req [KStor::Message::Base] client request
      def handle_request(user, sid, req)
        unless @request_handlers.key?(req.class)
          raise Error.for_code('REQ/UNKNOWN', req.type)
        end

        klass, args = __send__(@request_handlers[req.class], user, req)
        klass.new(args, { session_id: sid })
      end
    end
  end
end
