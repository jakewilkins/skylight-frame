# frozen_string_literal: true

require_relative "auth"
require_relative "calendar"
require_relative "frame"
require_relative "photo_methods"

require "net/http"
require "json"

module Skylight
  class Client
    HOST = "https://app.ourskylight.com"

    include Skylight::Calendar
    include Skylight::Frame
    include Skylight::PhotoMethods

    attr_reader :config

    def initialize(config = Skylight::Config.load)
      @config = config
    end

    def get(path, params = nil)
      ensure_valid_token!

      uri = URI.join(HOST, path)
      uri.query = URI.encode_www_form(params) if params

      req = Net::HTTP::Get.new(uri)
      headers.each { |k, v| req[k] = v }

      request(req)
    end

    def post(path, body)
      ensure_valid_token!

      uri = URI.join(HOST, path)

      req = Net::HTTP::Post.new(uri)
      headers.each { |k, v| req[k] = v }
      req["Content-Type"] = "application/json"
      req.body = body.to_json

      request(req)
    end

    def request(req)
      res = Net::HTTP.start(req.uri.host, use_ssl: true) do |http|
        http.request(req)
      end

      case res
      when Net::HTTPOK
        if res["content-type"]&.include?("application/json")
          JSON.parse(res.body)
        else
          res.body
        end
      else
        Cmd.debug "Unexpected response: #{res.class} - #{res.code}\n#{res.body}"
        raise "Unexpected response: #{res.code}"
      end
    end

    def headers
      {
        Accept: 'application/json',
        'User-Agent': 'SkylightMobile/2.2.2 (ios 26.3.1)',
        Authorization: "Bearer #{config.auth_string}"
      }
    end

    private

    def ensure_valid_token!
      return unless config.token_expired?

      Cmd.debug "Token expired, attempting refresh..."

      if config.refresh_token
        begin
          token_data = Skylight::Auth.refresh(config.refresh_token)
          store_tokens(token_data)
          Cmd.debug "Token refreshed successfully."
          return
        rescue StandardError => e
          Cmd.debug "Refresh failed: #{e.message}, attempting full re-login..."
        end
      end

      # Refresh unavailable or failed — try full re-login with stored credentials
      creds = config.credentials
      unless creds
        raise Skylight::Error, "Token expired and no refresh token or stored credentials available. Run `skylight-frame login` first."
      end

      begin
        token_data = Skylight::Auth.login(creds["email"], creds["password"])
        store_tokens(token_data)
        Cmd.debug "Re-authenticated successfully."
      rescue StandardError => e
        raise Skylight::Error, "Automatic re-authentication failed: #{e.message}. Run `skylight-frame login` to re-authenticate."
      end
    end

    def store_tokens(token_data)
      Skylight::Config::AuthorizationProvider.update(
        "access_token" => token_data["access_token"],
        "refresh_token" => token_data["refresh_token"],
        "expires_in" => token_data["expires_in"],
        "created_at" => token_data["created_at"]
      )
      config.reload!
    end
  end
end
