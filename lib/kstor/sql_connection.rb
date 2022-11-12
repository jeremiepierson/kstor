# frozen_string_literal: true

require 'kstor/log'
require 'kstor/error'

require 'sqlite3'

module KStor
  # Error: can't open database file.
  class CantOpenDatabase < Error
    error_code 'SQL/CANTOPEN'
    error_message "Can't open database file at %s"
  end

  # Execute SQL commands in a per-thread SQLite connection.
  class SQLConnection
    # Create a new SQL connection.
    #
    # @param file_path [String] path to SQLite database
    # @return [KStor::SQLConnection] the new connection
    def initialize(file_path)
      @file_path = file_path
    end

    # Execute SQL statement.
    #
    # @param sql [String] SQL statement
    # @param params [Array] parameters to fill placeholders in the statement
    # @return [Any] Whatever SQLite returns
    def execute(sql, *params, &)
      database.execute(sql, *params, &)
    end

    # Last generated ID (from an INSERT statement).
    #
    # @return [Integer] generated ID from last insert statement.
    def last_insert_row_id
      database.last_insert_row_id
    end

    # Execute given block of code in a database transaction.
    #
    # @return [Any] Whatever the block returns
    def transaction(&block)
      result = nil
      database.transaction do |db|
        result = block.call(db)
      end

      result
    end

    private

    def database
      key = :kstor_db_connection
      setup_thread_connection(key)
      db = Thread.current[key]
      return db unless db.closed?

      Log.warn('sqlite: bad connection, will re-connect')
      db.close
      Thread.current[k] = nil
      setup_thread_connection(key)
    end

    def setup_thread_connection(key)
      return if Thread.current[key]

      Log.debug(
        "sqlite: initializing connection in thread #{Thread.current.name}"
      )
      Thread.current[key] = connect(@file_path)
      Log.debug("sqlite: opened #{@file_path}")

      Thread.current[key]
    end

    def connect(file_path)
      db = SQLite3::Database.new(file_path)
      db.results_as_hash = true
      db.type_translation = SQLite3::Translator.new
      db.execute('PRAGMA foreign_keys = ON;')

      db
    rescue SQLite3::CantOpenException
      raise Error.for_code('SQL/CANTOPEN', file_path)
    end
  end
end
