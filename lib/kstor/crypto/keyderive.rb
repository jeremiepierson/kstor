# frozen_string_literal: true

require 'openssl'
require 'json'
require 'base64'

module KStor
  module Crypto
    module V1
      class KeyDeriveParams
        attr_accessor :salt
        attr_accessor :iter
        attr_accessor :key_len
        attr_accessor :hash

        def initialize(salt, iter, key_len, hash)
          @salt = salt
          @iter = iter
          @key_len = key_len
          @hash = hash
        end

        def serialize
          JSON.generate('salt' => Base64.strict_encode64(@salt),
                        'iter' => @iter, 'key_len' => @key_len, 'hash' => @hash)
        end

        def self.generate
          new(OpenSSL::Random.random_bytes(16), 20_000, 64, 'sha512')
        end

        def self.unserialize(str)
          h = JSON.parse(str)
          h['salt'] = Base64.strict_decode64(h['salt'])

          new(*h.values_at('salt', 'iter', 'key_len', 'hash'))
        end
      end

      class SecretBox
        def initialize(params)
          @params = params
        end

        def key_derive(password)
          OpenSSL::KDF.pbkdf2_hmac(
            password,
            salt: @params.salt, iterations: @params.iter,
            length: @params.key_len, hash: @params.hash
          )
        end

        def encrypt(password, data)
          key = key_derive(password)
        end

        def decrypt(data)
        end
      end

      def secret_box_seal(secret_key, data)
      end

      def secret_box_unseal(secret_key, data)
      end

      def box_seal(public_encrypt_key, private_sign_key, data)
      end

      def box_unseal(private_decrypt_key, public_verify_key, data)
      end

      def key_derive(password)
      end

      class SecretBox
        def seal(data, secret_key)
          cipher = OpenSSL::Cipher::AES256.new(:CBC).encrypt
          cipher.key = secret_key
          iv = cipher.random_iv
          ciphertext = cipher.update(data) + cipher.final

          [iv, ciphertext].map { |x| Base64.strict_encode64(x) }.join('$')
        end

        def unseal(data, secret_key)
          tmp = data.split('$', 2)
          iv, ciphertext = tmp.map { |x| Base64.strict_decode64(x) }

          cipher = OpenSSL::Cipher::AES256.new(:CBC).decrypt
          cipher.key = secret_key
          cipher.iv = iv
          cipher.update(ciphertext) + cipher.final
        end
      end

      class EncryptKey
        def encrypt(plaintext)
          @key.public_encrypt(plaintext)
        end
      end

      class DecryptKey
        def decrypt(ciphertext)
          @key.private_decrypt(ciphertext)
        end

        def encrypt_key
          @key.public_key
        end
      end

      class SignKey
        def sign(data)
          @key.sign(data)
        end
      end

      class VerifyKey
        def verify(signed_data)
          @key.verify(signed_data)
        end
      end

      module_function

      def key_derive(password, params = nil)
        params ||= key_derive_default_params
        OpenSSL::KDF.pbkdf2_hmac(
          password,
          salt: params['salt'], iterations: params['iter'],
          length: params['key_len'], hash: params['hash']
        )
      end

      def key_derive_default_params
        { 'salt' => OpenSSL::Random.random_bytes(16),
          'iter' => 20_000,
          'key_len' => 64,
          'hash' => 'sha512' }
      end

      def key_derive_params_serialize(params = {})
        h = params.merge(key_derive_default_params)
        h['salt'] = Base64.strict_encode64(h['salt'])

        params.to_json
      end

      def key_derive_params_unserialize(str)
        h = JSON.parse(str)
        h['salt'] = Base64.strict_decode64(h['salt'])

        h
      end
    end
  end
end
