# frozen_string_literal: true

require 'yaml'

require 'kstor/init_system'

module KStor
  # Configuration items stored as YAML.
  class Config
    # Default values for configuration items.
    #
    # They are used when loading configuration from a file, and for defining
    # accessor methods.
    #
    # @!attribute [r] database
    #   @return [String] path to SQLite database file
    #
    # @!attribute [r] socket
    #   @return [String] path to KStor server listening socket
    #
    # @!attribute [r] nworkers
    #   @return [Integer] number of worker threads
    #
    # @!attribute [r] session_idle_timeout
    #   @return [Integer] seconds of inactivity before a session is closed
    #
    # @!attribute [r] session_life_timeout
    #   @return [Integer] seconds before a session is closed
    DEFAULTS = {
      'database' => '/var/lib/kstor/kstor.sqlite',
      'socket' => InitSystem.default_socket_path,
      'nworkers' => 5,
      'session_idle_timeout' => 15 * 60,
      'session_life_timeout' => 4 * 60 * 60,
      'log_level' => 'warn'
    }.freeze

    class << self
      # Load configuration from a file.
      #
      # For each missing configuration item in file, use the default from
      # DEFAULTS.
      #
      # @param path [String] path to config file
      # @return [KStor::Config] configuration object
      def load(path)
        hash = if path && File.file?(path)
                 YAML.load_file(path)
               else
                 {}
               end
        new(hash)
      end
    end

    # Create configuration from hash data.
    #
    # @param hash [Hash] configuration items
    def initialize(hash)
      @data = DEFAULTS.merge(hash)
    end

    DEFAULTS.each_key do |k|
      define_method(k.to_sym) do
        @data[k]
      end
    end
  end
end
