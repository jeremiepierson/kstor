# frozen_string_literal: true

require 'json'

module KStor
  module Message
    # Internal exception when a request is received with neither a session ID
    # nor a login/password pair.
    #
    # We can't use a KStor::Error here because kstor/error.rb require()s
    # kstor/message.rb .
    class RequestMissesAuthData < RuntimeError
    end

    # Response data was invalid JSON.
    class UnparsableResponse < RuntimeError
    end
  end
end

require 'kstor/message/error'

require 'kstor/message/ping'
require 'kstor/message/pong'

require 'kstor/message/group_create'
require 'kstor/message/group_created'

require 'kstor/message/group_rename'
require 'kstor/message/group_updated'

require 'kstor/message/group_delete'
require 'kstor/message/group_deleted'

require 'kstor/message/group_search'
require 'kstor/message/group_list'

require 'kstor/message/group_get'
require 'kstor/message/group_info'

require 'kstor/message/user_create'
require 'kstor/message/user_created'

require 'kstor/message/user_activate'
require 'kstor/message/user_updated'

require 'kstor/message/secret_create'
require 'kstor/message/secret_created'

require 'kstor/message/secret_delete'
require 'kstor/message/secret_deleted'

require 'kstor/message/secret_search'
require 'kstor/message/secret_list'

require 'kstor/message/secret_unlock'
require 'kstor/message/secret_value'

require 'kstor/message/secret_update_meta'
require 'kstor/message/secret_update_value'
require 'kstor/message/secret_updated'

KStor::Message.register_all_message_types
