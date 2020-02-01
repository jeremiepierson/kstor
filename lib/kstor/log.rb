# frozen_string_literal: true

require 'journald/logger'

module KStor
  # Central logging to systemd-journald.
  module Log
    class << self
      def exception(exc)
        logger.exception(exc)
      end

      def debug(msg)
        logger.debug(msg)
      end

      def info(msg)
        logger.info(msg)
      end

      def notice(msg)
        logger.notice(msg)
      end

      def warn(msg)
        logger.warn(msg)
      end

      def error(msg)
        logger.error(msg)
      end

      def critical(msg)
        logger.critical(msg)
      end

      def alert(msg)
        logger.alert(msg)
      end

      def emergency(msg)
        logger.emergency(msg)
      end

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
