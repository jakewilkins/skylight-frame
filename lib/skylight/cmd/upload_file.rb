# frozen_string_literal: true

require "optparse"

module Skylight
  module Cmd
    module UploadFile
      class UploadFileArgs
        attr_reader :frame, :calendar, :paths

        def initialize
          @frame = nil
          @calendar = nil
          @paths = []
        end

        def []=(key, value)
          case key
          when :frame
            @frame = value
          when :calendar
            @calendar = value
          when :path
            @paths << value
          else
            raise ArgumentError, "Unknown key: #{key}"
          end
        end

        def to_h
          instance_variables.each_with_object({}) do |var, hash|
            hash[var.to_s.delete("@")] = instance_variable_get(var)
          end
        end

        alias inspect to_h
        alias to_s inspect
      end

      def self.command
        "upload-file"
      end

      def self.help
        "Upload a file to the Skylight Frame"
      end

      def self.usage
        "#{command} -f [FRAME] -p [PATH]"
      end

      def self.args(argv)
        options = UploadFileArgs.new
        ArgParser.parse(argv, into: options)
        options
      end

      def self.valid?(args)
        return false if args.paths.empty?
        return false if args.frame.nil? && args.calendar.nil?

        true
      end

      ArgParser = OptionParser.new do |opts|
        opts.banner = "Usage: #{usage}"

        opts.on("-f", "--frame FRAME", "Frame to upload file to")
        opts.on("-c", "--calendar CALENDAR", "Calendar to upload file to")
        opts.on("-p", "--path PATH", "File path to upload")

        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit
        end
      end

      def self.execute(config, args)
        client = Skylight::Client.new(config)

        if args.frame
          client.send_photos_to_frame(frame_name: args.frame, photo_paths: args.paths)
        elsif args.calendar
          client.send_photos_to_calendar(calendar_name: args.calendar, photo_paths: args.paths)
        end
      end
    end
  end
end
