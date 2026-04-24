# frozen_string_literal: true

require_relative "frame"
require_relative "calendar"
require_relative "photo_methods"

require "net/http"
require "json"

module Skylight
  class Client
    HOST = "https://app.ourskylight.com"

    include Skylight::Frame
    include Skylight::Calendar
    include Skylight::PhotoMethods

    class UnknownDeviceError < RuntimeError
      attr_reader :name

      def initialize(name)
        @name = name
        super("Device ID not found with name: #{name}")
      end
    end

    attr_reader :config

    def initialize(config = Skylight::Config.load)
      @config = config
    end

    def get(path, params = nil)
      uri = URI.join(HOST, path)
      uri.query = URI.encode_www_form(params) if params

      req = Net::HTTP::Get.new(uri)
      headers.each { |k, v| req[k] = v }

      request(req)
    end

    def post(path, body)
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
  end
end
