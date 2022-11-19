# frozen_string_literal: true

require 'etc'
require 'fileutils'
require 'json'
require 'slop'
require 'socket'

require 'kstor/message'
require 'kstor/client/state'
require 'kstor/client/subcommands'

module KStor
  module Client
    # KStor command-line client.
    class CommandLine
      include SubCommands

      # Create new command-line client.
      def initialize
        @progr = File.basename($PROGRAM_NAME)
        @config = State.load_config(@progr)
        @user = user_from_argv
      end

      # Read command-line args, send request to server and display results..
      def run
        request_type = ARGV.shift.to_sym
        resp = send_request(request_type)
        handle_error!(resp) if resp.error?

        puts format_response(resp)
        return unless resp.respond_to?(:session_id)

        File.open(State.session_id_file(@progr, @user), 'w') do |f|
          f.puts(resp.session_id)
        end
      end

      private

      def format_response(resp)
        data = resp.args.dup
        data.delete('session_id')
        JSON.pretty_generate(data)
      end

      def reorganize_secret_meta_args(req)
        req.args['meta'] = {
          'app' => req.args.delete('app'),
          'database' => req.args.delete('database'),
          'login' => req.args.delete('login'),
          'server' => req.args.delete('server'),
          'url' => req.args.delete('url')
        }
        req.args['meta'].compact!
        req
      end

      def handle_error!(resp)
        if resp.code == 'AUTH/BADSESSION'
          FileUtils.rm(State.session_id_file(@progr, @user))
          warn('session expired')
        else
          warn(resp.args['message'])
        end
        exit 1
      end

      def send_request(request_type)
        meth = method_name(request_type)

        req = __send__(meth)
        socket = UNIXSocket.new(@config['socket'])
        socket.send(req.serialize, 0)

        data, = socket.recvfrom(4096)
        Message::Base.parse(data)
      rescue Message::UnparsableResponse
        warn('Invalid response from server; look at logs!')
        exit(1)
      end

      def method_name(request_type)
        if request_type.nil?
          base_usage
          exit 0
        end
        unless KStor::Message::Base.type?(request_type)
          warn("Unknown request type #{request_type.inspect}")
          base_usage
          exit 1
        end
        request_type
      end

      def user_from_argv
        md = /^(-u|--user)$/.match(ARGV.first)
        md ? ARGV.shift(2).last : Etc.getlogin
      end

      def base_usage
        puts "usage: #{@progr} [--user USER] <req-type> [--help | REQ-ARGS]"
        request_types = KStor::Message::Base.types
                                            .select(&:request)
                                            .map(&:type)
                                            .map(&:to_s)
                                            .sort
        puts "request types:\n  #{request_types.join("\n  ")}"
      end

      def ask_password
        require 'io/console'

        $stdout.print 'Password: '
        password = $stdin.noecho(&:gets)
        $stdout.puts('')

        password.chomp
      end

      def auth
        session_id = State.load_session_id(@progr, @user)

        if session_id
          { session_id: }
        else
          { login: @user, password: ask_password }
        end
      end

      def request_with_meta(type, &block)
        args = parse_opts(type) { |o| block.call(o) }
        args['meta'] = {
          'app' => args.delete('app'),
          'database' => args.delete('database'),
          'login' => args.delete('login'),
          'server' => args.delete('server'),
          'url' => args.delete('url')
        }
        args['meta'].compact!
        KStor::Message::Base.for_type(type, args, auth)
      end

      def request(type, &block)
        args = parse_opts(type) { |o| block.call(o) }
        KStor::Message::Base.for_type(type, args, auth)
      end

      def parse_opts(request_type)
        opts = Slop.parse do |o|
          o.banner = <<-EOUSAGE
          usage: #{@progr} [--user USER] #{request_type} [--help | REQ-ARGS]
          EOUSAGE
          o.on('-h', '--help', 'show this text') do
            puts o
            exit 0
          end
          o.separator('')
          yield o
        end
        opts.to_hash.compact.transform_keys(&:to_s)
      end
    end
  end
end

