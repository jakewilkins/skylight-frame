# frozen_string_literal: true

require "test_helper"

class Skylight::TestFrame < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Skylight::Frame::VERSION
  end

  def test_it_does_something_useful
    assert true, "oh fo sho"
  end
end
