# frozen_string_literal: true

require "keychain"

module Skylight
  class Config
    attr_reader :auth_string

    def self.set_auth_string(password)
      if item = Keychain.generic_passwords.where(service: 'SkylightFrameAuth').first
        item.password = password
        item.save!
        return
      end

      Keychain.generic_passwords.create(
        service: 'SkylightFrameAuth',
        account: 'bob',
        password: password
      )
    end

    def self.load
      auth_string = Keychain.generic_passwords.where(
        service: 'SkylightFrameAuth',
      ).first.password

      new(auth_string:)
    end

    def initialize(auth_string:)
      @auth_string = auth_string
    end
  end
end
