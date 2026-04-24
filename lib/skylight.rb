# frozen_string_literal: true

require_relative "skylight/frame/version"
require_relative "skylight/config"
require_relative "skylight/client"

module Skylight
  class Error < StandardError; end

  class UnknownDeviceError < RuntimeError
    attr_reader :name

    def initialize(name)
      @name = name
      super("Device ID not found with name: #{name}")
    end
  end
end
