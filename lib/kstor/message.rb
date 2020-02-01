# frozen_string_literal: true

require 'json'

module KStor
  # A user request or response.
  class Message
    attr_reader :type
    attr_reader :args

    def initialize(type, args)
      @type = type
      @args = args
    end

    def to_h
      { 'type' => @type, 'args' => @args }
    end

    def serialize
      to_h.to_json
    end
  end

  # A user request.
  class Request < Message
    attr_reader :login
    attr_reader :password

    def initialize(login, password, *args)
      @login = login
      @password = password
      super(*args)
    end

    def inspect
      format(
        '#<Request:%<id>x @login=%<login>s @password="******" @args=%<args>s',
        id: __id__,
        login: @login.inspect,
        args: @args.inspect
      )
    end

    def self.parse(str)
      data = JSON.parse(str)
      new(
        data['login'], data['password'],
        data['type'], data['args']
      )
    end

    def to_h
      super.merge('login' => @login, 'password' => @password)
    end
  end

  # Response to a user request.
  class Response < Message
  end
end
