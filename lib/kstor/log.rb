# frozen_string_literal: true

module KStor
  # Central logging to systemd-journald.
  module Log
    # Simple logger using Ruby Logger.
    #
    # It just defines some convenient methods that Journald::Logger has.
    #
    # @api private
    class SimpleLogger
      # Create a new logger.
      #
      # @return [KStor::Log::SimpleLogger] a simple logger to STDOUT
      def initialize
        @logger = Logger.new($stdout)
      end

      # Set minimum log level
      #
      # @param lvl [Integer] log level from constants in Logger class
      def level=(lvl)
        @logger.level = lvl
      end

      # Log a debug message.
      #
      # @param msg [String] message
      def debug(msg)
        @logger.debug(msg)
      end

      # Log an informative message.
      #
      # @param msg [String] message
      def info(msg)
        @logger.info(msg)
      end

      # Log a warning.
      #
      # @param msg [String] message
      def warn(msg)
        @logger.warn(msg)
      end

      # Log an error message.
      #
      # @param msg [String] message
      def error(msg)
        @logger.error(msg)
      end

      # Log an exception with full backtrace and all.
      #
      # @param exc [Exception] an exception
      def exception(exc)
        @logger.error(exc.full_message)
      end

      alias notice info
      alias critical error
      alias alert error
      alias emergency error
    end

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

      # Log a critical error message.
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
        if logger.respond_to?(:min_priority)
          logger.min_priority = lvl
        else
          logger.level = lvl
        end
      end

      private

      def logger
        @logger ||= create_logger
      end

      def create_logger
        if ENV['INIT_IS_SYSTEMD']
          setup_systemd_logger
        else
          setup_stdout_logger
        end
      end

      def setup_systemd_logger
        require 'journald/logger'

        const_set(:DEBUG, Journald::LOG_DEBUG)
        const_set(:INFO, Journald::LOG_INFO)
        const_set(:WARN, Journald::LOG_WARN)
        const_set(:ERROR, Journald::LOG_ERROR)

        Journald::Logger.new('kstor')
      end

      def setup_stdout_logger
        require 'logger'

        const_set(:DEBUG, Logger::DEBUG)
        const_set(:INFO, Logger::INFO)
        const_set(:WARN, Logger::WARN)
        const_set(:ERROR, Logger::ERROR)

        SimpleLogger.new
      end
    end
  end
end
