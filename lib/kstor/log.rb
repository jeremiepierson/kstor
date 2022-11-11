# frozen_string_literal: true

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
        lvl = level_str_to_int(lvl) if lvl.respond_to?(:to_str)

        if logger.respond_to?(:min_priority)
          logger.min_priority = lvl
        else
          logger.level = lvl
        end
      end

      private

      def level_str_to_int(value)
        case value
        when /^debug$/i then const_get(:DEBUG)
        when /^info$/i then const_get(:INFO)
        when /^warn$/i then const_get(:WARN)
        when /^error$/i then const_get(:ERROR)
        else
          raise "Unknown log level #{value.inspect}"
        end
      end

      def logger
        @logger ||= create_logger
      end
    end
  end
end

if ENV['INIT_IS_SYSTEMD']
  require 'kstor/log/systemd_logger'
else
  require 'kstor/log/simple_logger'
end
