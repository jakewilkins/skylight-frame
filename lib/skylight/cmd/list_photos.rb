# frozen_string_literal: true

require "optparse"

module Skylight
  module Cmd
    module ListPhotos
      class ListPhotosArgs
        attr_reader :frame, :calendar

        def initialize
          @frame = nil
          @calendar = nil
        end

        def []=(key, value)
          case key
          when :frame
            @frame = value
          when :calendar
            @calendar = value
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
        "list-photos"
      end

      def self.help
        "List the photos on a Skylight Frame or Calendar"
      end

      def self.usage
        "#{command} -f [FRAME] | -c [CALENDAR]"
      end

      def self.args(argv)
        options = ListPhotosArgs.new
        ArgParser.parse(argv, into: options)
        options
      end

      def self.valid?(args)
        !(args.frame.nil? && args.calendar.nil?)
      end

      ArgParser = OptionParser.new do |opts|
        opts.banner = "Usage: #{usage}"

        opts.on("-f", "--frame FRAME", "Frame to list photos for")
        opts.on("-c", "--calendar CALENDAR", "Calendar to list photos for")

        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit
        end
      end

      def self.execute(config, args)
        client = Skylight::Client.new(config)

        photos = if args.frame
          client.list_frame_photos(frame_name: args.frame)
        else
          client.list_calendar_photos(calendar_name: args.calendar)
        end

        photos.each do |photo|
          puts " - #{photo.id} #{photo.asset_type} #{photo.created_at}"
        end
      end
    end
  end
end
