# frozen_string_literal: true

require 'test_helper'

class TestKStorCryptoASCIIArmor < Minitest::Test
  def test_roundtrip
    s = 'çui-ci est en UTF-8 héhéhé'.dup.force_encoding('ASCII-8BIT')
    roundtrip = KStor::Crypto::ASCIIArmor.decode(
      KStor::Crypto::ASCIIArmor.encode(s)
    )

    assert_equal(s, roundtrip)
  end
end
