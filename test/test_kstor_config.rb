# frozen_string_literal: true

require 'test_helper'

class TestKStorConfig < Minitest::Test
  FIXTURE = {
    'database' => 'truc.sqlite',
    'socket' => 'truc.socket'
  }.freeze

  def setup
    @cfg = KStor::Config.new(FIXTURE)
  end

  def test_access
    assert_equal(FIXTURE['database'], @cfg.database)
    assert_equal(FIXTURE['socket'], @cfg.socket)
    assert_equal(KStor::Config::DEFAULTS['nworkers'], @cfg.nworkers)
  end
end
