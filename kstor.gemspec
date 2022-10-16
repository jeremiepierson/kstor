# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'kstor/version'

Gem::Specification.new do |s|
  s.required_ruby_version = '>= 3.1.0'
  s.metadata = {
    'rubygems_mfa_required' => 'true'
  }

  s.name = 'kstor'
  s.version = KStor::VERSION
  s.summary = 'KStor secret server'
  s.description = <<-EODESCR
    KStor stores and shares secrets among teams of users. This is the server
    part, supporting a command-line client and a web user interface.
  EODESCR
  s.authors = ['Jérémie Pierson']
  s.email = 'jeremie.pierson@arlol.net'
  s.license = 'GPL-3.0-or-later'
  s.files = Dir['lib/**/*']
  s.files += ['bin/kstor-srv.rb']
  s.bindir = 'bin'
  s.executables << 'kstor-srv.rb'
  s.executables << 'kstor.rb'
  s.extra_rdoc_files = ['README.md']

  s.add_runtime_dependency 'journald-logger', '~> 3.1'
  s.add_runtime_dependency 'rbnacl', '~> 7.1'
  s.add_runtime_dependency 'sd_notify', '~> 0.1'
  s.add_runtime_dependency 'sqlite3', '~> 1.5'
end
