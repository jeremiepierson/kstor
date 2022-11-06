# frozen_string_literal: true

module KStor
  module Controller
    # Common code for all controllers (except RequestHandler).
    class Base
      class << self
        attr_accessor :request_types
        attr_accessor :response_types

        def handles?(type)
          @request_types.include?(type)
        end
      end

      def initialize(store)
        @store = store
        @request_handlers = self.class.request_types.to_h do |type|
          meth = "handle_#{type}".to_sym
          [type, meth]
        end
      end

      def handle_request(user, req)
        unless @request_handlers.key?(req.type)
          raise Error.for_code('REQ/UNKNOWN', req.type)
        end

        __send__(@request_handlers[req.type], user, req)
      end
    end
  end
end
