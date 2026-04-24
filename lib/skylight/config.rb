# frozen_string_literal: true

require "json"

module Skylight
  class Config
    module AuthorizationProvider
      module_function

      VALID_BACKENDS = %i(keychain env).freeze
      ENV_KEY = "SKYLIGHT_FRAME_AUTH"
      KEYCHAIN_SERVICE_NAME = "SkylightFrameAuth"

      def backend(value = nil)
        if value
          raise "Invalid Authorization Provider: #{value}" unless VALID_BACKENDS.include?(value)

          @backend = value
        else
          @backend
        end
      end

      # Returns a Hash of stored auth data, or nil if nothing is stored.
      # Handles legacy bare-token strings by wrapping them as { "access_token" => value }.
      def get
        raw = raw_get
        return nil if raw.nil? || raw.empty?

        parse_stored_value(raw)
      end

      # Accepts a Hash and stores it as a JSON string.
      def set(data)
        raw_set(data.to_json)
      end

      # Merges new key/value pairs into the existing stored Hash and saves.
      def update(new_data)
        current = get || {}
        set(current.merge(new_data))
      end

      # Returns a single field from the stored data.
      def get_field(key)
        get&.dig(key)
      end

      private

      module_function

      def raw_get
        if ENV.key?(ENV_KEY)
          return ENV[ENV_KEY]
        end

        return nil unless backend == :keychain

        Keychain.generic_passwords.where(
          service: KEYCHAIN_SERVICE_NAME
        ).first&.password
      end

      def raw_set(value)
        if backend == :keychain
          if (item = Keychain.generic_passwords.where(service: KEYCHAIN_SERVICE_NAME).first)
            item.password = value
            item.save!
            return
          end

          Keychain.generic_passwords.create(
            service: KEYCHAIN_SERVICE_NAME,
            account: 'skylight-frame',
            password: value
          )
        elsif backend == :env
          ENV[ENV_KEY] = value
        end
      end

      def parse_stored_value(raw)
        data = JSON.parse(raw)
        data.is_a?(Hash) ? data : { "access_token" => raw }
      rescue JSON::ParserError
        # Legacy bare-token string
        { "access_token" => raw }
      end
    end

    attr_reader :data

    def self.load
      new(data: AuthorizationProvider.get || {})
    end

    def initialize(data: {})
      @data = data
    end

    def auth_string
      data["access_token"]
    end

    def refresh_token
      data["refresh_token"]
    end

    def credentials
      email = data["email"]
      password = data["password"]
      return nil unless email && password

      { "email" => email, "password" => password }
    end

    def token_expired?
      created_at = data["created_at"]
      expires_in = data["expires_in"]
      return true unless created_at && expires_in

      Time.now.to_i >= (created_at.to_i + expires_in.to_i)
    end

    # Re-read from the store, e.g. after tokens have been refreshed.
    def reload!
      @data = AuthorizationProvider.get || {}
      self
    end
  end
end

if RUBY_PLATFORM.include?("darwin")
  require "keychain"
  Skylight::Config::AuthorizationProvider.backend(:keychain)
else
  Skylight::Config::AuthorizationProvider.backend(:env)
end
