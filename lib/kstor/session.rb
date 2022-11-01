# frozen_string_literal: true

require 'mutex_m'

module KStor
  # A user session in memory.
  class Session
    attr_reader :id
    attr_reader :user
    attr_reader :secret_key
    attr_reader :created_at
    attr_reader :updated_at

    def initialize(sid, user, secret_key)
      @id = sid
      @user = user
      @secret_key = secret_key
      @created_at = Time.now
      @updated_at = Time.now
    end

    def update
      @updated_at = Time.now
      self
    end

    def self.create(user, secret_key)
      sid = SecureRandom.urlsafe_base64(16)
      new(sid, user, secret_key)
    end
  end

  # Collection of user sessions (in memory)
  #
  # FIXME make it thread safe!
  class SessionStore
    def initialize(idle_timeout, life_timeout)
      @idle_timeout = idle_timeout
      @life_timeout = life_timeout
      @sessions = {}
      @sessions.extend(Mutex_m)
    end

    def <<(session)
      @sessions.synchronize do
        @sessions[session.id] = session
      end
    end

    def [](sid)
      @sessions.synchronize do
        s = @sessions[sid.to_s]
        return nil if s.nil?

        if invalid?(s)
          @sessions.delete(s.id)
          return nil
        end

        s.update
      end
    end

    def purge
      now = Time.now
      @sessions.synchronize do
        @sessions.delete_if { |_, s| invalid?(s, now) }
      end
    end

    private

    def invalid?(session, now = Time.now)
      return true if session.created_at + @life_timeout < now
      return true if session.updated_at + @idle_timeout < now

      false
    end
  end
end
