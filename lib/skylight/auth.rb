# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "securerandom"
require "digest"
require "base64"

module Skylight
  module Auth
    BASE_URL = "https://app.ourskylight.com"
    CLIENT_ID = "skylight-mobile"
    REDIRECT_URI = "skylight-family://welcome"
    SCOPE = "everything"

    DEVICE_METADATA = {
      "skylight_api_client_device_fingerprint" => nil, # set lazily
      "skylight_api_client_device_platform" => "ios",
      "skylight_api_client_device_name" => "iPad",
      "skylight_api_client_device_os_version" => "26.3",
      "skylight_api_client_device_app_version" => "2.3.0",
      "skylight_api_client_device_hardware" => "iPad Pro (12.9-inch) (3rd generation)",
      "source" => "js-mobile"
    }.freeze

    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.3.1 Safari/605.1.15"

    module_function

    # --- Public API ---

    # Generate a PKCE verifier and S256 challenge pair.
    def generate_pkce
      verifier = SecureRandom.urlsafe_base64(32).tr("=", "") # 43 chars, URL-safe
      digest = Digest::SHA256.digest(verifier)
      challenge = Base64.urlsafe_encode64(digest).tr("=", "")
      { verifier: verifier, challenge: challenge }
    end

    # Walk the full 5-step OAuth flow. Returns a Hash with token data.
    def login(email, password)
      pkce = generate_pkce
      state = SecureRandom.hex(5)
      cookie_jar = {}

      # Step 1 — Initiate OAuth Authorize
      cookie_jar = initiate_authorize(pkce, state, cookie_jar)

      # Step 2 — Load login form, extract CSRF token
      csrf_token = load_login_form(cookie_jar)

      # Step 3 — Submit credentials
      redirect_url, cookie_jar = submit_credentials(cookie_jar, csrf_token, email, password)

      # Step 4 — Follow redirect back to OAuth authorize, extract auth code
      auth_code, returned_state = follow_authorize_redirect(cookie_jar, redirect_url)
      raise "OAuth state mismatch" unless returned_state == state

      # Step 5 — Exchange code for tokens
      exchange_code(auth_code, pkce[:verifier])
    end

    # Exchange a refresh token for a new access token.
    def refresh(refresh_token)
      uri = URI("#{BASE_URL}/oauth/token")

      body = URI.encode_www_form(
        "grant_type" => "refresh_token",
        "client_id" => CLIENT_ID,
        "refresh_token" => refresh_token
      )

      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/x-www-form-urlencoded"
      req["Accept"] = "application/json"
      req["User-Agent"] = USER_AGENT
      req.body = body

      res = perform_request(req)
      raise "Token refresh failed: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPOK)

      JSON.parse(res.body)
    end

    # Check whether a token is expired given its created_at and expires_in.
    def token_expired?(created_at, expires_in)
      return true unless created_at && expires_in

      Time.now.to_i >= (created_at.to_i + expires_in.to_i)
    end

    # --- Private helpers ---

    # Step 1: GET /oauth/authorize — capture session cookie from redirect.
    def initiate_authorize(pkce, state, cookie_jar)
      uri = URI("#{BASE_URL}/oauth/authorize")
      uri.query = URI.encode_www_form(
        "client_id" => CLIENT_ID,
        "response_type" => "code",
        "scope" => SCOPE,
        "redirect_uri" => REDIRECT_URI,
        "code_challenge" => pkce[:challenge],
        "code_challenge_method" => "S256",
        "state" => state,
        "prompt" => "login"
      )

      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      apply_cookies(req, cookie_jar)

      res = perform_request(req)
      raise "Step 1 failed: expected 302, got #{res.code}" unless res.is_a?(Net::HTTPRedirection)

      merge_cookies(cookie_jar, res)
    end

    # Step 2: GET /auth/session/new — extract CSRF authenticity_token.
    def load_login_form(cookie_jar)
      uri = URI("#{BASE_URL}/auth/session/new")

      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      apply_cookies(req, cookie_jar)

      res = perform_request(req)
      raise "Step 2 failed: expected 200, got #{res.code}" unless res.is_a?(Net::HTTPOK)

      merge_cookies(cookie_jar, res)
      extract_csrf_token(res.body)
    end

    # Step 3: POST /auth/session — submit credentials, capture redirect URL.
    def submit_credentials(cookie_jar, csrf_token, email, password)
      uri = URI("#{BASE_URL}/auth/session")

      body = URI.encode_www_form(
        "authenticity_token" => csrf_token,
        "email" => email,
        "password" => password
      )

      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/x-www-form-urlencoded"
      req["Origin"] = BASE_URL
      req["Referer"] = "#{BASE_URL}/auth/session/new"
      req["User-Agent"] = USER_AGENT
      apply_cookies(req, cookie_jar)
      req.body = body

      res = perform_request(req)
      raise "Step 3 failed: expected 302, got #{res.code}" unless res.is_a?(Net::HTTPRedirection)

      merge_cookies(cookie_jar, res)
      [res["location"], cookie_jar]
    end

    # Step 4: GET the redirect URL from Step 3 — extract authorization code.
    def follow_authorize_redirect(cookie_jar, url)
      uri = URI(url)

      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      apply_cookies(req, cookie_jar)

      res = perform_request(req)
      raise "Step 4 failed: expected 302, got #{res.code}" unless res.is_a?(Net::HTTPRedirection)

      location = URI(res["location"])
      params = URI.decode_www_form(location.query || "").to_h
      code = params["code"]
      state = params["state"]

      raise "Step 4: no authorization code in redirect" unless code

      [code, state]
    end

    # Step 5: POST /oauth/token — exchange auth code for tokens.
    def exchange_code(code, pkce_verifier)
      uri = URI("#{BASE_URL}/oauth/token")

      fingerprint = device_fingerprint

      fields = {
        "grant_type" => "authorization_code",
        "client_id" => CLIENT_ID,
        "scope" => SCOPE,
        "redirect_uri" => REDIRECT_URI,
        "code" => code,
        "code_verifier" => pkce_verifier,
        "skylight_api_client_device_fingerprint" => fingerprint,
        "skylight_api_client_device_platform" => DEVICE_METADATA["skylight_api_client_device_platform"],
        "skylight_api_client_device_name" => DEVICE_METADATA["skylight_api_client_device_name"],
        "skylight_api_client_device_os_version" => DEVICE_METADATA["skylight_api_client_device_os_version"],
        "skylight_api_client_device_app_version" => DEVICE_METADATA["skylight_api_client_device_app_version"],
        "skylight_api_client_device_hardware" => DEVICE_METADATA["skylight_api_client_device_hardware"],
        "source" => DEVICE_METADATA["source"]
      }

      body = URI.encode_www_form(fields)

      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/x-www-form-urlencoded"
      req["Accept"] = "application/json"
      req["User-Agent"] = USER_AGENT
      req.body = body

      res = perform_request(req)
      raise "Step 5 failed: expected 200, got #{res.code} #{res.body}" unless res.is_a?(Net::HTTPOK)

      JSON.parse(res.body)
    end

    # --- Cookie and HTTP helpers ---

    def apply_cookies(req, cookie_jar)
      return if cookie_jar.empty?

      req["Cookie"] = cookie_jar.map { |k, v| "#{k}=#{v}" }.join("; ")
    end

    def merge_cookies(cookie_jar, response)
      Array(response.get_fields("set-cookie")).each do |raw|
        # Parse "name=value; path=/; ..." — we only need name=value
        pair = raw.split(";").first.strip
        name, value = pair.split("=", 2)
        cookie_jar[name] = value if name && value
      end
      cookie_jar
    end

    def extract_csrf_token(html)
      # Try the meta tag first, then the hidden input
      if (match = html.match(/<meta\s+name="csrf-token"\s+content="([^"]+)"/))
        return match[1]
      end
      if (match = html.match(/<input[^>]+name="authenticity_token"[^>]+value="([^"]+)"/))
        return match[1]
      end

      raise "Could not extract CSRF token from login form"
    end

    # Returns a stable device fingerprint UUID, generating and storing one if needed.
    def device_fingerprint
      stored = Config::AuthorizationProvider.get_field("device_fingerprint")
      return stored if stored

      fingerprint = SecureRandom.uuid
      Config::AuthorizationProvider.update("device_fingerprint" => fingerprint)
      fingerprint
    end

    def perform_request(req)
      uri = req.uri
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(req)
      end
    end

    private_class_method :initiate_authorize, :load_login_form, :submit_credentials,
                         :follow_authorize_redirect, :exchange_code,
                         :apply_cookies, :merge_cookies, :extract_csrf_token,
                         :device_fingerprint, :perform_request
  end
end
