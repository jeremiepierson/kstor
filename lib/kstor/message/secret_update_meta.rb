# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to update secret metadata.
    class SecretUpdateMeta < Base
      message_type :secret_update_meta, request: true

      arg :meta
      arg :secret_id
    end
  end
end
