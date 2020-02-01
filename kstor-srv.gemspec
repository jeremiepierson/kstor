# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'kstor/version'

Gem::Specification.new do |s|
  s.name = 'kstor-srv'
  s.version = KStor::VERSION
  s.summary = 'KStor secret server'
  s.description = <<-EODESCR
    KStor stores and shares secrets among teams of users. This is the server
    part, supporting a command-line client and a web user interface.
  EODESCR
  s.authors = ['Jérémie Pierson']
  s.email = 'lerougearlo@gmail.com'
  s.license = 'GPL-3.0-or-later'
  s.files = Dir['lib/**/*']
  s.files += ['bin/kstor-srv.rb']
  s.bindir = 'bin'
  s.executables << 'kstor-srv.rb'
  s.extra_rdoc_files = ['README']
end
