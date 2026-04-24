# frozen_string_literal: true

require "test_helper"
require "skylight/auth"
require "skylight/config"

class Skylight::TestAuth < Minitest::Test
  def test_generate_pkce_returns_verifier_and_challenge
    pkce = Skylight::Auth.generate_pkce

    assert pkce.key?(:verifier), "PKCE should include :verifier"
    assert pkce.key?(:challenge), "PKCE should include :challenge"
    assert pkce[:verifier].length >= 43, "Verifier should be at least 43 chars"
    assert_match(/\A[A-Za-z0-9_-]+\z/, pkce[:verifier], "Verifier should be URL-safe")
    assert_match(/\A[A-Za-z0-9_-]+\z/, pkce[:challenge], "Challenge should be URL-safe (no padding)")
  end

  def test_generate_pkce_produces_correct_s256_challenge
    pkce = Skylight::Auth.generate_pkce

    # Recompute the challenge from the verifier
    digest = Digest::SHA256.digest(pkce[:verifier])
    expected = Base64.urlsafe_encode64(digest).tr("=", "")

    assert_equal expected, pkce[:challenge], "Challenge should be S256 of verifier"
  end

  def test_generate_pkce_produces_unique_values
    a = Skylight::Auth.generate_pkce
    b = Skylight::Auth.generate_pkce

    refute_equal a[:verifier], b[:verifier], "Each call should produce a unique verifier"
  end

  def test_token_expired_with_valid_token
    created_at = Time.now.to_i - 100
    expires_in = 7200

    refute Skylight::Auth.token_expired?(created_at, expires_in)
  end

  def test_token_expired_with_expired_token
    created_at = Time.now.to_i - 8000
    expires_in = 7200

    assert Skylight::Auth.token_expired?(created_at, expires_in)
  end

  def test_token_expired_with_nil_values
    assert Skylight::Auth.token_expired?(nil, nil)
    assert Skylight::Auth.token_expired?(nil, 7200)
    assert Skylight::Auth.token_expired?(Time.now.to_i, nil)
  end
end
