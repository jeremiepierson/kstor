#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'kstor/config'
require 'kstor/store'
require 'kstor/controller'
require 'kstor/server'
require 'kstor/log'

KStor::Log.reporting_level = Journald::LOG_DEBUG

config = KStor::Config.load(ARGV.shift)

store = KStor::Store.new(config['database'])
server = KStor::Server.new(
  controller: KStor::Controller.new(store),
  socket_path: config['socket'],
  nworkers: config['nworkers']
)
server.start
