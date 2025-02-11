# frozen_string_literal: true

require_relative "frame"

require "net/http"
require "json"

module Skylight
  class Client
    HOST = "https://app.ourskylight.com"

    include Skylight::Frame

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
        debug "Unexpected response: #{res.class} - #{res.code}\n#{res.body}"
        raise "Unexpected response: #{res.code}"
      end
    end

    def upload_to(url:, file_path:)
      uri = URI(url)
      req = Net::HTTP::Put.new(uri)
      req.body = IO.binread(file_path)
      req["Content-Type"] = "application/octet-stream"
      req["Content-Length"] = File.size(file_path)

      request(req)
    end

    def headers
      {
        Accept: 'application/json',
        'User-Agent': 'Skylight/22822 CFNetwork/3826.400.120 Darwin/24.3.0',
        Authorization: "Basic #{config.auth_string}"
      }
    end
  end
end
