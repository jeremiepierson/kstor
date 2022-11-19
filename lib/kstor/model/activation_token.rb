# frozen_string_literal: true

module KStor
  module Model
    # A secret token that is needed to activate a new user account.
    class ActivationToken < Base
      property :user_id
      property :token
      property :not_before
      property :not_after

      # True if token is currently valid.
      def valid?
        now = Time.now
        return false if now.to_i < not_before
        return false if now.to_i > not_after

        true
      end

      # Create new random activation token.
      #
      # @param user_id [Integer] token is for this user
      # @param lifespan [Integer] token is valid for this number of seconds
      # @return [KStor::Model::ActivationToken] a new random token
      def self.create(user_id, lifespan)
        now = Time.now
        not_before = now.to_i
        not_after = now.to_i + lifespan
        value = SecureRandom.urlsafe_base64(16)
        new(user_id:, token: value, not_before:, not_after:)
      end
    end
  end
end
