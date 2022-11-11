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

    # Create a new user session.
    #
    # @param sid [String] Session ID
    # @param user [KStor::Model::User] user owning the session
    # @param secret_key [KStor::Crypto::SecretKey] user secret key, derived
    #   from password
    # @return [KStor::Session] new session
    def initialize(sid, user, secret_key)
      @id = sid
      @user = user
      @secret_key = secret_key
      @created_at = Time.now
      @updated_at = Time.now
    end

    # Update access time, for idle sessions weeding.
    #
    # @return [KStor::Session] updated session
    def update
      @updated_at = Time.now
      self
    end

    # Create a new session for a user.
    #
    # @param user [KStor::Model::User] user owning the session
    # @param secret_key [KStor::Crypto::SecretKey] user secret key, derived
    #   from password
    # @return [KStor::Session] new session with a random SID
    def self.create(user, secret_key)
      sid = SecureRandom.urlsafe_base64(16)
      new(sid, user, secret_key)
    end
  end

  # Collection of user sessions (in memory).
  #
  # Concurrent accesses are synchronized on a mutex.
  class SessionStore
    # Create new session store.
    #
    # @param idle_timeout [Integer] sessions that aren't updated for this
    #   number of seconds are considered invalid
    # @param life_timeout [Integer] sessions that are older than this number of
    #   seconds are considered invalid
    # @return [KStor::SessionStore] a new session store.
    def initialize(idle_timeout, life_timeout)
      @idle_timeout = idle_timeout
      @life_timeout = life_timeout
      @sessions = {}
      @sessions.extend(Mutex_m)
    end

    # Add a session to the store.
    #
    # @param session [KStor::Session] session to store
    def <<(session)
      @sessions.synchronize do
        @sessions[session.id] = session
      end
    end

    # Fetch a session from it's ID.
    #
    # @param sid [String] session ID to lookup
    # @return [KStor::Session, nil] session or nil if session ID was not found
    #   or session has expired
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

    # Delete expired sessions.
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
