# frozen_string_literal: true

require 'journald/logger'

module KStor
  # rubocop:disable Style/Documentation
  module Log
    # rubocop:enable Style/Documentation

    DEBUG = Journald::LOG_DEBUG
    INFO = Journald::LOG_INFO
    WARN = Journald::LOG_WARNING
    ERROR = Journald::LOG_ERR

    class << self
      # Create new systemd journald logger
      def create_logger
        Journald::Logger.new('kstor')
      end
    end
  end
end
