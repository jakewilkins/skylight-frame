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

    def send_photos_to_frame(frame_name:, photo_paths:)
      perform_send_photos(device_id: find_frame(frame_name).id, photo_paths:)
    end

    def list_frame_photos(frame_name:)
      list_photos(device_id: find_frame(frame_name).id)
    end

    def delete_frame_photos(frame_name:, photo_ids:)
      device_id = find_frame(frame_name).id

      photo_ids.each { |photo_id| delete_photo(device_id:, photo_id:) }
    end

    def find_frame(frame_name)
      frame = list_frames.find { |f| f.name == frame_name }
      raise Skylight::UnknownDeviceError, frame_name unless frame

      frame
    end
  end
end
