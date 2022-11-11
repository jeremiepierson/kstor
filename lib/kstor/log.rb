# frozen_string_literal: true

require 'journald/logger'

module KStor
  # Central logging to systemd-journald.
  module Log
    class << self
      # Log an exception.
      #
      # @param exc [Exception] exception to log.
      def exception(exc)
        logger.exception(exc)
      end

      # Log a debug message.
      #
      # @param msg [String] message
      def debug(msg)
        logger.debug(msg)
      end

      # Log an informative message.
      #
      # @param msg [String] message
      def info(msg)
        logger.info(msg)
      end

      # Log a notice message.
      #
      # @param msg [String] message
      def notice(msg)
        logger.notice(msg)
      end

      # Log a warning.
      #
      # @param msg [String] message
      def warn(msg)
        logger.warn(msg)
      end

      # Log an error message.
      #
      # @param msg [String] message
      def error(msg)
        logger.error(msg)
      end

      # Log a crticial error message.
      #
      # @param msg [String] message
      def critical(msg)
        logger.critical(msg)
      end

      # Log an alert message.
      #
      # @param msg [String] message
      def alert(msg)
        logger.alert(msg)
      end

      # Log an emergency message.
      #
      # @param msg [String] message
      def emergency(msg)
        logger.emergency(msg)
      end

      # Set reporting level.
      def reporting_level=(lvl)
        logger.min_priority = lvl
      end

      private

      def logger
        @logger ||= Journald::Logger.new('kstor')
      end
    end
  end
end
