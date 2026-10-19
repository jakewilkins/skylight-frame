# frozen_string_literal: true

require "digest"

require_relative "frame/version"

module Skylight
  module PhotoMethods
    class PhotoResponse
      attr_reader :id, :asset_type, :status, :created_at, :asset_url, :attributes

      def initialize(id:, asset_type:, status:, created_at:, asset_url:, attributes:)
        @id = id
        @asset_type = asset_type
        @status = status
        @created_at = created_at
        @asset_url = asset_url
        @attributes = attributes
      end

      def self.from_api(message)
        attrs = message["attributes"]

        new(
          id: message["id"].to_s,
          asset_type: attrs["asset_type"],
          status: attrs["status"],
          created_at: attrs["created_at"],
          asset_url: attrs["asset_url"],
          attributes: message
        )
      end
    end

    FIRST_PAGE_TOKEN = "__START__"

    # How long perform_send_photos waits for uploaded photos to show up in
    # the device's photo list.
    UPLOAD_LIST_ATTEMPTS = 5
    UPLOAD_LIST_DELAY = 2 # seconds

    # All photos on the device, newest first. Pass a block to stop paging
    # early: it's given each page's photos and paging stops once it returns
    # true.
    def list_photos(device_id:)
      photos = []
      page_token = FIRST_PAGE_TOKEN

      loop do
        response = get("/api/frames/#{device_id}/messages", { page_token: page_token })
        page = response["data"].map { |message| PhotoResponse.from_api(message) }
        photos.concat(page)

        meta = response["meta"] || {}
        break unless meta["has_next"] && meta["next_page_token"]
        break if block_given? && yield(page)

        page_token = meta["next_page_token"]
      end

      photos
    end

    def delete_photo(device_id:, photo_id:)
      Skylight.debug("Deleting photo #{photo_id} from device_id #{device_id}")
      delete("/api/frames/#{device_id}/messages/#{photo_id}")
    end

    # Uploads the photos and returns the PhotoResponses the device now has
    # for them, so callers can delete them later. The upload API doesn't say
    # which photos it creates, so this diffs the device's photo list from
    # before and after the upload.
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

      newest_before = newest_photo_id(device_id:)

      Skylight.debug("Uploading photos to device_id #{device_id} with messages: #{messages}")

      upload_urls_response = post("/api/message_upload_urls", {
        frame_ids: [device_id],
        messages: messages
      }).dig("data", "upload_urls")

      if upload_urls_response.first.key?("error")
        raise "Error getting upload urls: #{upload_urls_response.first['error']}"
      end

      Skylight.debug("Received upload urls: #{upload_urls_response}")

      upload_urls_response.each_with_index do |upload_url_data, index|
        file_path = photo_paths[index]
        upload_url = upload_url_data["url"]

        Skylight.debug("Uploading file to #{upload_url} with file path: #{file_path}")
        result = upload_to(url: upload_url, file_path: file_path)

        raise "Error uploading file: #{result['error']}" if result.is_a?(Hash) && result&.key?("error")

        Skylight.debug("Uploaded file with result: #{result.nil? || result.empty? ? 'success' : result}")
      end

      photos_added_since(device_id:, photo_id: newest_before, expected: photo_paths.size)
    end

    def upload_to(url:, file_path:)
      uri = URI(url)
      req = Net::HTTP::Put.new(uri)
      req.body = IO.binread(file_path)
      req["Content-Type"] = "application/octet-stream"
      req["Content-Length"] = File.size(file_path)

      request(req)
    end

    private

    def newest_photo_id(device_id:)
      response = get("/api/frames/#{device_id}/messages", { page_token: FIRST_PAGE_TOKEN })
      response["data"].first&.dig("id")&.to_s
    end

    # Photos newer than photo_id (nil means the device was empty), waiting
    # briefly for all `expected` of them to show up.
    def photos_added_since(device_id:, photo_id:, expected:)
      added = []

      UPLOAD_LIST_ATTEMPTS.times do |attempt|
        sleep UPLOAD_LIST_DELAY if attempt.positive?

        photos = list_photos(device_id:) do |page|
          photo_id && page.any? { |photo| photo.id.to_i <= photo_id.to_i }
        end
        added = photos.select { |photo| photo_id.nil? || photo.id.to_i > photo_id.to_i }
        break if added.size >= expected

        Skylight.debug("Found #{added.size} of #{expected} uploaded photos, waiting...")
      end

      added
    end
  end
end
