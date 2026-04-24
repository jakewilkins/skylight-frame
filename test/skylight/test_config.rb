# frozen_string_literal: true

require "test_helper"
require "skylight/config"

class Skylight::TestConfig < Minitest::Test
  def setup
    # Use env backend for tests to avoid keychain dependency
    Skylight::Config::AuthorizationProvider.backend(:env)
    ENV.delete(Skylight::Config::AuthorizationProvider::ENV_KEY)
  end

  def teardown
    ENV.delete(Skylight::Config::AuthorizationProvider::ENV_KEY)
  end

  def test_auth_provider_stores_and_retrieves_json
    Skylight::Config::AuthorizationProvider.set({"access_token" => "abc123", "refresh_token" => "ref456"})
    data = Skylight::Config::AuthorizationProvider.get

    assert_equal "abc123", data["access_token"]
    assert_equal "ref456", data["refresh_token"]
  end

  def test_auth_provider_update_merges_data
    Skylight::Config::AuthorizationProvider.set({"access_token" => "old"})
    Skylight::Config::AuthorizationProvider.update("refresh_token" => "new_ref")

    data = Skylight::Config::AuthorizationProvider.get
    assert_equal "old", data["access_token"]
    assert_equal "new_ref", data["refresh_token"]
  end

  def test_auth_provider_get_field
    Skylight::Config::AuthorizationProvider.set({"access_token" => "tok"})

    assert_equal "tok", Skylight::Config::AuthorizationProvider.get_field("access_token")
    assert_nil Skylight::Config::AuthorizationProvider.get_field("nonexistent")
  end

  def test_auth_provider_handles_legacy_bare_token
    ENV[Skylight::Config::AuthorizationProvider::ENV_KEY] = "bare_token_string"
    data = Skylight::Config::AuthorizationProvider.get

    assert_equal({"access_token" => "bare_token_string"}, data)
  end

  def test_auth_provider_returns_nil_when_empty
    assert_nil Skylight::Config::AuthorizationProvider.get
  end

  def test_config_auth_string_returns_access_token
    config = Skylight::Config.new(data: {"access_token" => "mytoken"})
    assert_equal "mytoken", config.auth_string
  end

  def test_config_refresh_token
    config = Skylight::Config.new(data: {"refresh_token" => "myrefresh"})
    assert_equal "myrefresh", config.refresh_token
  end

  def test_config_credentials
    config = Skylight::Config.new(data: {"email" => "a@b.com", "password" => "secret"})
    assert_equal({"email" => "a@b.com", "password" => "secret"}, config.credentials)
  end

  def test_config_credentials_returns_nil_when_missing
    config = Skylight::Config.new(data: {"access_token" => "tok"})
    assert_nil config.credentials
  end

  def test_config_token_expired
    config = Skylight::Config.new(data: {"created_at" => Time.now.to_i - 8000, "expires_in" => 7200})
    assert config.token_expired?
  end

  def test_config_token_not_expired
    config = Skylight::Config.new(data: {"created_at" => Time.now.to_i, "expires_in" => 7200})
    refute config.token_expired?
  end

  def test_config_load_from_env
    Skylight::Config::AuthorizationProvider.set({"access_token" => "envtok", "refresh_token" => "envref"})
    config = Skylight::Config.load

    assert_equal "envtok", config.auth_string
    assert_equal "envref", config.refresh_token
  end

  def test_config_reload
    Skylight::Config::AuthorizationProvider.set({"access_token" => "first"})
    config = Skylight::Config.load
    assert_equal "first", config.auth_string

    Skylight::Config::AuthorizationProvider.update("access_token" => "second")
    config.reload!
    assert_equal "second", config.auth_string
  end
end
