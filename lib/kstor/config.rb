# frozen_string_literal: true

require 'yaml'

module KStor
  # Configuration items stored as YAML.
  class Config
    DEFAULTS = {
      'database' => 'data/db.sqlite',
      'socket' => 'run/kstor-server.socket',
      'nworkers' => 5
    }.freeze

    class << self
      def load(path)
        hash = if path && File.file?(path)
                 YAML.load_file(path)
               else
                 {}
               end
        new(DEFAULTS.merge(hash))
      end
    end

    def initialize(hash)
      @data = hash
    end

    def [](key)
      @data[key]
    end
  end
end
