# frozen_string_literal: true

require 'kstor/error'
require 'kstor/log'
require 'kstor/store'
require 'kstor/message'
require 'kstor/controller/authentication'
require 'kstor/controller/secret'
require 'kstor/controller/users'
require 'kstor/controller/request_handler'

module KStor
  # Error: user was not allowed to access application.
  class UserNotAllowed < Error
    error_code 'AUTH/FORBIDDEN'
    error_message 'User %s not allowed.'
  end

  # Error: invalid session ID
  class InvalidSession < Error
    error_code 'AUTH/BADSESSION'
    error_message 'Invalid session ID %s'
  end

  class MissingLoginPassword < Error
    error_code 'AUTH/MISSING'
    error_message 'Missing login and password'
  end

  # Error: unknown request type.
  class UnknownRequestType < Error
    error_code 'REQ/UNKNOWN'
    error_message 'Unknown request type %s'
  end

  # Error: missing request argument.
  class MissingMessageArgument < Error
    error_code 'REQ/MISSINGARGS'
    error_message 'Missing argument(s) %s for message type %s'
  end

  class UnknownGroup < KStor::Error
    error_code 'STORE/UNKNOWNGROUP'
    error_message 'Unknown group with ID #%d'
  end

  class UnknownUser < KStor::Error
    error_code 'STORE/UNKNOWNUSER'
    error_message 'Unknown user with ID #%d'
  end

  class GroupHasMembers < KStor::Error
    error_code 'STORE/GROUPHASMEMBERS'
    error_message "Group #%d has members and can't be deleted"
  end

  class UnknownGroupPrivateKey < KStor::Error
    error_code 'STORE/UNKNOWNGROUPPRIVK'
    error_message "Current user doesn't have access to private key of group #%d"
  end
end
