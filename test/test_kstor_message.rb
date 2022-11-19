# frozen_string_literal: true

require 'test_helper'

require 'json'

class TestKStorMessage < Minitest::Test
  FIXTURE = {
    'database' => 'truc.sqlite',
    'socket' => 'truc.socket'
  }.freeze

  def make_req_sid(sid, **args)
    KStor::Message::Ping.new(
      args.transform_keys(&:to_s),
      { session_id: sid }
    )
  end

  def make_resp(sid, **args)
    KStor::Message::Pong.new(
      args.transform_keys(&:to_s),
      { session_id: sid }
    )
  end

  def make_req_login(login, password, **args)
    KStor::Message::Ping.new(
      args.transform_keys(&:to_s),
      { login:, password: }
    )
  end

  def test_create
    m = make_req_sid('sid', payload: 'Ga Bu Zo Meu')
    h = {
      'type' => 'ping', 'args' => { 'payload' => 'Ga Bu Zo Meu' },
      'session_id' => 'sid'
    }

    assert_equal(:ping, m.type)
    assert_equal({ 'payload' => 'Ga Bu Zo Meu' }, m.args)
    assert_equal(h, m.to_h)
    assert_equal(h.to_json, m.serialize)
  end

  def test_login_request
    req = make_req_login('bob', 'secret', payload: 'foo')

    assert_equal('bob', req.login)
    assert_equal('secret', req.password)
    assert_equal('bob', req.to_h['login'])
    assert_equal('ping', req.to_h['type'])
  end

  def test_session_request
    req = make_req_sid('sid', payload: 'foo')

    assert_equal('sid', req.session_id)
    assert_equal('sid', req.to_h['session_id'])
    assert_equal('ping', req.to_h['type'])
  end

  def test_parse_request_roundtrip
    lreq = make_req_login('bob', 'secret', payload: 'foo')
    sreq = make_req_sid('sid', payload: 'foo')

    assert_equal(lreq.to_h, KStor::Message::Base.parse(lreq.serialize).to_h)
    assert_equal(sreq.to_h, KStor::Message::Base.parse(sreq.serialize).to_h)
  end

  def test_parse_request_raises
    m = make_req_sid('sid', payload: 'Ga Bu Zo Meu')
    h = m.to_h
    h.delete('session_id')
    str = JSON.generate(h)

    assert_raises(KStor::Message::RequestMissesAuthData) do
      KStor::Message::Base.parse(str)
    end
  end

  def test_inspect_password_sid
    lreq = make_req_login('bob', 'secret', payload: 'foo')
    sreq = make_req_sid('secret', payload: 'foo')

    refute_match(/secret/, lreq.inspect)
    refute_match(/secret/, sreq.inspect)
  end

  def test_response
    resp = make_resp('secret', payload: 'blah')

    assert_equal('secret', resp.session_id)
    assert_equal(
      resp.to_h,
      KStor::Message::Base.parse(resp.serialize).to_h
    )
    assert_raises(KStor::Message::UnparsableResponse) do
      KStor::Message::Base.parse('[')
    end
  end

  def test_response_error
    resp = make_resp('secret', payload: 'blah')
    err = KStor::Message::Error.new(
      { 'code' => 'BLAHRGH', 'message' => 'Alas, the blorb was blahrghed' }
    )

    refute_predicate(resp, :error?)
    assert_predicate(err, :error?)
  end
end
