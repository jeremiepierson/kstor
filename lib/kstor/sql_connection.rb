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
    def initialize(file_path)
      @file_path = file_path
    end

    def execute(sql, *params, &block)
      database.execute(sql, *params, &block)
    end

    def last_insert_row_id
      database.last_insert_row_id
    end

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

      Log.info(
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

      db
    rescue SQLite3::CantOpenException
      raise Error.for_code('SQL/CANTOPEN', file_path)
    end
  end
end
