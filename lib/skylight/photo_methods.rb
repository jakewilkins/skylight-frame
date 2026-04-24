# frozen_string_literal: true

require_relative "frame/version"

module Skylight
  module PhotoMethods
    def perform_send_photos(device_id:, photo_paths:)
      messages = photo_paths.map do |photo_path|
        extension = File.extname(photo_path)
        sha256 = Digest::SHA256.file(photo_path)

        extension = if extension == ".jpeg"
          "jpg"
        elsif extension == ".tiff"
          "tif"
        else
          extension[1..] # Remove the leading dot
        end

        {
          "ext": extension,
          "caption": "",
          "local_file_id": sha256.hexdigest
        }
      end

      Cmd.debug("Uploading photos to device_id #{device_id} with messages: #{messages}")

      upload_urls_response = post("/api/message_upload_urls", {
        frame_ids: [device_id],
        messages: messages
      }).dig("data", "upload_urls")

      if upload_urls_response.first.key?("error")
        raise "Error getting upload urls: #{upload_urls_response.first['error']}"
      end

      Cmd.debug("Received upload urls: #{upload_urls_response}")

      upload_urls_response.each_with_index do |upload_url_data, index|
        file_path = photo_paths[index]
        upload_url = upload_url_data["url"]

        Cmd.debug("Uploading file to #{upload_url} with file path: #{file_path}")
        result = upload_to(url: upload_url, file_path: file_path)

        raise "Error uploading file: #{result['error']}" if result.is_a?(Hash) && result&.key?("error")

        puts "Uploaded file with result: #{result.nil? ? 'success' : result}"
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
  end
end
