# frozen_string_literal: true

require 'json'
require 'securerandom'

require 'kstor/crypto'

module KStor
  # Model objects.
  module Model
    # @!macro [new] dsl_model_properties_rw
    #   @!attribute $1
    #     @return returns value of property $1
  end
end

require 'kstor/model/base'
require 'kstor/model/activation_token'
require 'kstor/model/group'
require 'kstor/model/keychain_item'
require 'kstor/model/secret_meta'
require 'kstor/model/secret'
require 'kstor/model/user'
