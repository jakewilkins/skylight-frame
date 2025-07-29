# frozen_string_literal: true

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

      def get
        auth_string = if ENV.key?(ENV_KEY)
          ENV[ENV_KEY]
        end

        return auth_string if auth_string
        return nil unless backend == :keychain

        Keychain.generic_passwords.where(
          service: 'SkylightFrameAuth'
        ).first&.password
      end

      def set(value)
        if backend == :keychain
          if (item = Keychain.generic_passwords.where(service: KEYCHAIN_SERVICE_NAME).first)
            item.password = password
            item.save!
            return
          end

          Keychain.generic_passwords.create(
            service: KEYCHAIN_SERVICE_NAME,
            account: 'bob',
            password: password
          )
        elsif backend == :env
          ENV[ENV_KEY] = value
        end
      end
    end

    attr_reader :auth_string

    def self.load
      new(auth_string: AuthorizationProvider.get)
    end

    def initialize(auth_string:)
      @auth_string = auth_string
    end
  end
end

if RUBY_PLATFORM.include?("darwin")
  require "keychain"
  Skylight::Config::AuthorizationProvider.backed(:keychain)
else
  Skylight::Config::AuthorizationProvider.backed(:env)
end
