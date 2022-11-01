# frozen_string_literal: true

require 'yaml'

module KStor
  # Configuration items stored as YAML.
  class Config
    DEFAULTS = {
      'database' => 'data/db.sqlite',
      'socket' => 'run/kstor-server.socket',
      'nworkers' => 5,
      'session_idle_timeout' => 15 * 60,
      'session_life_timeout' => 4 * 60 * 60
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

    DEFAULTS.each_key do |k|
      define_method(k.to_sym) do
        @data[k]
      end
    end
  end
end
