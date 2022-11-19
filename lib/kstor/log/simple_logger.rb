# frozen_string_literal: true

require 'logger'

module KStor
  # rubocop:disable Style/Documentation
  module Log
    # rubocop:enable Style/Documentation

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
        progname = File.basename($PROGRAM_NAME)
        @logger = Logger.new($stdout, progname:)
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

      # Log a fatal error message.
      #
      # @param msg [String] message
      def fatal(msg)
        @logger.fatal(msg)
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

    DEBUG = Logger::DEBUG
    INFO = Logger::INFO
    WARN = Logger::WARN
    ERROR = Logger::ERROR
    FATAL = Logger::FATAL

    class << self
      # Create new simple logger to stdout
      def create_logger
        SimpleLogger.new
      end
    end
  end
end
