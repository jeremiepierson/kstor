# frozen_string_literal: true

require 'fileutils'
require 'yaml'

module KStor
  module Client
    # Manage KStor client configuration and state on disk.
    module State
      class << self
        # Default client config.
        DEFAULT_CONFIG = {
          'socket' => '/run/kstor.socket'
        }.freeze

        # Load client config from disk.
        def load_config(progr)
          DEFAULT_CONFIG.merge(load_config_file(progr))
        end

        # Path to session ID file on disk.
        def session_id_file(progr, login)
          dir = File.join(xdg_runtime, progr)
          FileUtils.mkdir_p(dir)
          file = File.join(dir, "session-id-#{login}")
          FileUtils.touch(file)
          FileUtils.chmod(0o600, file)
          file
        end

        # Load session ID from disk.
        def load_session_id(progr, login)
          sid = nil
          File.open(session_id_file(progr, login)) { |f| sid = f.read.chomp }
          sid = nil if sid.empty?

          sid
        end

        private

        def xdg_config
          ENV.fetch('XDG_CONFIG_HOME', File.join(Dir.home, '.config'))
        end

        def xdg_state
          ENV.fetch('XDG_STATE_HOME', File.join(Dir.home, '.local', 'state'))
        end

        def xdg_runtime
          dir = ENV.fetch('XDG_RUNTIME_DIR', nil)
          return dir if dir

          warn('XDG_RUNTIME_DIR is undefined, using XDG_STATE_HOME instead')
          xdg_state
        end

        def config_file(progr)
          dir = File.join(xdg_config, progr)
          FileUtils.mkdir_p(dir)
          File.join(dir, 'config.yaml')
        end

        def load_config_file(progr)
          YAML.load_file(config_file(progr))
        rescue Errno::ENOENT
          {}
        end
      end
    end
  end
end
