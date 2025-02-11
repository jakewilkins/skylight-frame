# frozen_string_literal: true

require_relative "frame/version"

module Skylight
  module Frame
    class FrameResponse
      attr_reader :name, :id, :email, :attributes

      def initialize(name:, id:, email:, attributes:)
        @name = name
        @id = id
        @email = email
        @attributes = attributes
      end
    end

    def list_frames
      response = get("/api/frames/photo")

      response["data"].map do |frame|
        FrameResponse.new(
          name: frame["attributes"]["name"],
          id: frame["id"],
          email: frame["attributes"]["notification_email"],
          attributes: frame
        )
      end
    end

    def send_photos(frame_name:, photo_paths:)
      frame_id = list_frames.find { |frame| frame.name == frame_name }&.id
      messages = photo_paths.map do |photo_path|
        extension = File.extname(photo_path)
        sha256 = Digest::SHA256.file(photo_path)

        extension = case
        when extension == ".jpeg"
          "jpg"
        when extension == ".tiff"
          "tif"
        else
          extension[1..-1] # Remove the leading dot
        end

        {
          "ext": extension,
          "caption": "",
          "local_file_id": sha256.hexdigest,
        }
      end

      Cmd.debug("Uploading photos to frame #{frame_name}:#{frame_id} with messages: #{messages}")

      upload_urls_response = post("/api/message_upload_urls", {
        frame_ids: [frame_id],
        messages: messages
      }).dig("data", "upload_urls")

      if upload_urls_response.first.key?("error")
        raise "Error getting upload urls: #{upload_urls_response.first["error"]}"
      end

      Cmd.debug("Received upload urls: #{upload_urls_response}")

      upload_urls_response.each_with_index do |upload_url_data, index|
        file_path = photo_paths[index]
        upload_url = upload_url_data["url"]

        Cmd.debug("Uploading file to #{upload_url} with file path: #{file_path}")
        result = upload_to(url: upload_url, file_path: file_path)

        if result.is_a?(Hash) && result&.key?("error")
          raise "Error uploading file: #{result["error"]}"
        else
          puts "Uploaded file with result: #{result.nil? ? "success" : result}"
        end
      end
    end
  end
end
