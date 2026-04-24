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
      frame_id = list_frames.find { |frame| frame.name == frame_name }
      raise Skylight::UnknownDeviceError, frame_name unless frame_id

      perform_send_photos(device_id: frame_id.id, photo_paths:)
    end
  end
end
