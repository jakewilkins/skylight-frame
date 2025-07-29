# frozen_string_literal: true

module Skylight
  module Cmd
    module ListFrames
      def self.command
        "list-frames"
      end

      def self.help
        "List the frames for the Skylight Account"
      end

      def self.usage
        "#{command} [options]"
      end

      def self.args(_argv)
        nil
      end

      def self.valid?(args)
        !args
      end

      def self.execute(config)
        client = Skylight::Client.new(config)
        client.list_frames.each do |frame|
          puts " - #{frame.name}"
        end
      end
    end
  end
end
