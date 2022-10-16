#!/usr/bin/env ruby
# frozen_string_literal: true

require 'kstor/message'

require 'json'
require 'socket'

login = 'jpi'
password = 'secret'
request_type = ARGV.shift
request_args = JSON.parse(ARGV.shift)

hreq = {
  'login' => login, 'password' => password,
  'type' => request_type, 'args' => request_args
}
req = KStor::Request.parse(hreq.to_json)

s = UNIXSocket.new('/home/jpi/code/kstor/testworkdir/kstor.socket')
s.send(req.serialize, 0)
data, = s.recvfrom(4906)
puts data
