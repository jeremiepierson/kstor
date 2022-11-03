# frozen_string_literal: true

require 'yaml'

module KStor
  # Configuration items stored as YAML.
  class Config
    # Default values for configuration items.
    #
    # They are used when loading configuration from a file, and for defining
    # accessor methods.
    DEFAULTS = {
      'database' => 'data/db.sqlite',
      'socket' => 'run/kstor-server.socket',
      'nworkers' => 5,
      'session_idle_timeout' => 15 * 60,
      'session_life_timeout' => 4 * 60 * 60
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
        new(DEFAULTS.merge(hash))
      end
    end

    # Create configuration from hash data.
    #
    # @param hash [Hash] configuration items
    def initialize(hash)
      @data = hash
    end

    DEFAULTS.each_key do |k|
      define_method(k.to_sym) do
        @data[k]
      end
    end
  end
end
