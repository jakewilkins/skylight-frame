# frozen_string_literal: true

module Skylight
  module Calendar
    class CalendarResponse
      attr_reader :name, :id, :email, :attributes

      def initialize(name:, id:, email:, attributes:)
        @name = name
        @id = id
        @email = email
        @attributes = attributes
      end
    end

    def list_calendars
      response = get("/api/frames/calendar")

      response["data"].map do |frame|
        CalendarResponse.new(
          name: frame["attributes"]["name"],
          id: frame["id"],
          email: frame["attributes"]["notification_email"],
          attributes: frame
        )
      end
    end

    def send_photos_to_calendar(calendar_name:, photo_paths:)
      calendar_id = list_calendars.find { |cal| cal.name == calendar_name}
      raise Skylight::UnknownDeviceError, calendar_name unless calendar_id

      perform_send_photos(device_id: calendar_id.id, photo_paths:)
    end
  end
end
