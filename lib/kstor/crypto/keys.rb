# frozen_string_literal: true

module KStor
  module Crypto
    # Holds together a secret key value and the KDF associated parameters.
    class SecretKey
      # The secret key as a raw String
      attr_reader :value
      # KDF parameters as an ASCII-armored String
      attr_reader :kdf_params

      def initialize(value, kdf_params)
        @value = value
        @kdf_params = kdf_params
      end
    end

    # Holds together a public and private key pair.
    class KeyPair
      attr_reader :pubk
      attr_reader :privk

      def initialize(pubk, privk)
        @pubk = pubk
        @privk = privk
      end
    end
  end
end
