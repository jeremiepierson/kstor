# frozen_string_literal: true

module KStor
  # Cryptographic functions for KStor.
  module Crypto
    # Encode and decode binary data to ASCII.
    module ASCIIArmor
      class << self
        # ASCII-armor a String of bytes.
        #
        # @param bytes [String] raw string
        # @return [String] ASCII-armored string
        def encode(bytes)
          Base64.strict_encode64(bytes)
        end

        # Decode an ASCII-armored string back to raw data.
        #
        # @param str [String] ASCII-armored string
        # @return [String] raw string
        def decode(str)
          Base64.strict_decode64(str)
        end
      end
    end
  end
end
