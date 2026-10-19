# frozen_string_literal: true

module Skylight
  def self.debug(msg)
    return unless ENV["DEBUG"]

    $stderr.puts msg
  end
end
