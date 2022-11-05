# frozen_string_literal: true

require 'test_helper'

require 'json'

class TestKStorMessage < Minitest::Test
  FIXTURE = {
    'database' => 'truc.sqlite',
    'socket' => 'truc.socket'
  }.freeze

  def test_create
    m = KStor::Message.new('ping', { 'payload' => 'Ga Bu Zo Meu' })

    assert_equal('ping', m.type)
    assert_equal({ 'payload' => 'Ga Bu Zo Meu' }, m.args)
    assert_equal(
      { 'type' => 'ping', 'args' => { 'payload' => 'Ga Bu Zo Meu' } },
      m.to_h
    )
    assert_equal(
      { 'type' => 'ping', 'args' => { 'payload' => 'Ga Bu Zo Meu' } }.to_json,
      m.serialize
    )
  end

  def test_login_request
    req = KStor::LoginRequest.new('bob', 'secret', 'ping', {})

    assert_equal('bob', req.login)
    assert_equal('secret', req.password)
    assert_equal('bob', req.to_h['login'])
    assert_equal('ping', req.to_h['type'])
  end

  def test_session_request
    req = KStor::SessionRequest.new('sid', 'ping', {})

    assert_equal('sid', req.session_id)
    assert_equal('sid', req.to_h['session_id'])
    assert_equal('ping', req.to_h['type'])
  end

  def test_parse_request_roundtrip
    lreq = KStor::LoginRequest.new('bob', 'secret', 'ping', {})
    sreq = KStor::SessionRequest.new('sid', 'ping', {})

    assert_equal(lreq.to_h, KStor::Message.parse_request(lreq.serialize).to_h)
    assert_equal(sreq.to_h, KStor::Message.parse_request(sreq.serialize).to_h)
  end

  def test_parse_request_classes
    lreq = KStor::LoginRequest.new('bob', 'secret', 'ping', {})
    sreq = KStor::SessionRequest.new('sid', 'ping', {})

    assert_equal(
      KStor::LoginRequest,
      KStor::Message.parse_request(lreq.serialize).class
    )
    assert_equal(
      KStor::SessionRequest,
      KStor::Message.parse_request(sreq.serialize).class
    )
  end

  def test_parse_request_raises
    m = KStor::Message.new('ping', { 'payload' => 'Ga Bu Zo Meu' })

    assert_raises(KStor::RequestMissesAuthData) do
      KStor::Message.parse_request(m.serialize)
    end
  end

  def test_inspect_password_sid
    lreq = KStor::LoginRequest.new('bob', 'secret', 'ping', {})
    sreq = KStor::SessionRequest.new('secret', 'ping', {})

    refute_match(/secret/, lreq.inspect)
    refute_match(/secret/, sreq.inspect)
  end

  def test_response
    resp = KStor::Response.new('pong', 'payload' => 'blah')
    resp.session_id = 'secret'

    assert_equal('secret', resp.session_id)
    assert_equal(
      resp.serialize,
      KStor::Response.parse(resp.serialize).serialize
    )
    assert_raises(KStor::UnparsableResponse) { KStor::Response.parse('[') }
  end

  def test_response_error
    resp = KStor::Response.new('pong', 'payload' => 'blah')
    err = KStor::Response.new('error', {})

    refute_predicate(resp, :error?)
    assert_predicate(err, :error?)
  end
end
