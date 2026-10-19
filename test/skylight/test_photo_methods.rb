# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "skylight"

class Skylight::TestPhotoMethods < Minitest::Test
  # Records requests and answers them from canned responses instead of
  # hitting the network.
  class FakeClient < Skylight::Client
    attr_reader :calls

    def initialize(responses)
      super(Skylight::Config.new)
      @responses = responses
      @calls = []
    end

    def get(path, params = nil)
      respond(:get, path, params)
    end

    def post(path, body)
      respond(:post, path, body)
    end

    def delete(path)
      respond(:delete, path, nil)
    end

    def upload_to(url:, file_path:)
      @calls << [:put, url, file_path]
      ""
    end

    def sleep(_seconds); end

    private

    def respond(verb, path, params)
      @calls << [verb, path, params]
      queue = @responses.fetch([verb, path]) { raise "Unexpected #{verb.upcase} #{path}" }
      queue.is_a?(Array) ? queue.shift : queue
    end
  end

  MESSAGES_PATH = "/api/frames/3067654/messages"

  def api_message(id, asset_type: "photo")
    {
      "id" => id.to_s,
      "type" => "message_status",
      "attributes" => {
        "id" => id,
        "status" => "downloaded",
        "asset_type" => asset_type,
        "created_at" => "2026-10-18T14:00:00.000Z",
        "asset_url" => "https://example.test/#{id}.jpg"
      }
    }
  end

  def page(ids, next_page_token: nil)
    meta = { "has_next" => !next_page_token.nil? }
    meta["next_page_token"] = next_page_token if next_page_token
    { "data" => ids.map { |id| api_message(id) }, "meta" => meta }
  end

  def frames_response
    { "data" => [{ "id" => "3067654", "attributes" => { "name" => "Living Room" } }] }
  end

  def test_list_photos_follows_page_tokens
    client = FakeClient.new(
      [:get, MESSAGES_PATH] => [page([30, 29], next_page_token: "abc"), page([28])]
    )

    photos = client.list_photos(device_id: "3067654")

    assert_equal %w[30 29 28], photos.map(&:id)
    assert_equal "photo", photos.first.asset_type
    assert_equal [{ page_token: "__START__" }, { page_token: "abc" }],
                 client.calls.map(&:last)
  end

  def test_delete_photo_deletes_the_message
    client = FakeClient.new([:delete, "#{MESSAGES_PATH}/983661900"] => { "data" => {} })

    client.delete_photo(device_id: "3067654", photo_id: "983661900")

    assert_equal [[:delete, "#{MESSAGES_PATH}/983661900", nil]], client.calls
  end

  def test_delete_frame_photos_looks_up_the_frame_by_name
    client = FakeClient.new(
      [:get, "/api/frames/photo"] => frames_response,
      [:delete, "#{MESSAGES_PATH}/1"] => {},
      [:delete, "#{MESSAGES_PATH}/2"] => {}
    )

    client.delete_frame_photos(frame_name: "Living Room", photo_ids: %w[1 2])

    assert_equal [:delete, :delete], client.calls.drop(1).map(&:first)
  end

  def test_unknown_frame_name_raises
    client = FakeClient.new([:get, "/api/frames/photo"] => frames_response)

    assert_raises(Skylight::UnknownDeviceError) do
      client.list_frame_photos(frame_name: "Kitchen")
    end
  end

  def test_send_photos_returns_the_photos_it_added
    photo = Tempfile.new(["photo", ".jpeg"])
    photo.write("not really a jpeg")
    photo.close

    client = FakeClient.new(
      [:get, MESSAGES_PATH] => [
        page([100, 99]),                             # newest photo before upload
        page([101]),                                 # upload not listed yet...
        page([102, 101, 100], next_page_token: "x")  # ...now both are
      ],
      [:post, "/api/message_upload_urls"] => {
        "data" => { "upload_urls" => [{ "url" => "https://s3.test/a" }, { "url" => "https://s3.test/b" }] }
      }
    )

    added = client.perform_send_photos(device_id: "3067654", photo_paths: [photo.path, photo.path])

    assert_equal %w[102 101], added.map(&:id)
    post_body = client.calls.find { |call| call.first == :post }.last
    assert_equal "jpg", post_body[:messages].first[:ext]
    # Paging stops at the page holding the pre-upload photo.
    refute(client.calls.any? { |call| call.last == { page_token: "x" } })
  ensure
    photo&.unlink
  end

  def test_send_photos_to_an_empty_device_returns_everything
    photo = Tempfile.new(["photo", ".png"])
    photo.close

    client = FakeClient.new(
      [:get, MESSAGES_PATH] => [page([]), page([1])],
      [:post, "/api/message_upload_urls"] => { "data" => { "upload_urls" => [{ "url" => "https://s3.test/a" }] } }
    )

    added = client.perform_send_photos(device_id: "3067654", photo_paths: [photo.path])

    assert_equal %w[1], added.map(&:id)
  ensure
    photo&.unlink
  end
end
