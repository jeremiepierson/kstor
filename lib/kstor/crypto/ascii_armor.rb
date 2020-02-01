# frozen_string_literal: true

module KStor
  # Cryptographic functions for KStor.
  module Crypto
    class << self
      private

      # ASCII-armor a String of bytes.
      #
      # @param bytes [String] raw string
      # @return [String] ASCII-armored string
      def b2a(bytes)
        Base64.strict_encode64(bytes)
      end

      # Decode an ASCII-armored string back to raw data.
      #
      # @param str [String] ASCII-armored string
      # @return [String] raw string
      def a2b(str)
        Base64.strict_decode64(str)
      end

      # Decode an ASCII-armored public key.
      #
      # @param str [String] ASCII-armored public key
      # @return [RbNaCl::PublicKey] a raw public key
      def a2pubk(str)
        RbNaCl::PublicKey.new(a2b(str))
      end

      # Decode an ASCII-armored private key.
      #
      # @param str [String] ASCII-armored private key
      # @return [RbNaCl::PrivateKey] a raw private key
      def a2privk(str)
        RbNaCl::PrivateKey.new(a2b(str))
      end

      # ASCII-armor a raw private key.
      #
      # @param privk [RbNaCl::PrivateKey] a raw private key
      # @return [String] ASCII-armored private key
      def privk2a(privk)
        b2a(privk.to_bytes)
      end
    end
  end
end
