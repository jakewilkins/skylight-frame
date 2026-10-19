# frozen_string_literal: true

require "optparse"

module Skylight
  module Cmd
    module DeletePhoto
      class DeletePhotoArgs
        attr_reader :frame, :calendar, :ids

        def initialize
          @frame = nil
          @calendar = nil
          @ids = []
        end

        def []=(key, value)
          case key
          when :frame
            @frame = value
          when :calendar
            @calendar = value
          when :id
            @ids << value
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
        "delete-photo"
      end

      def self.help
        "Delete photos from a Skylight Frame or Calendar"
      end

      def self.usage
        "#{command} -f [FRAME] | -c [CALENDAR] -i [PHOTO ID]"
      end

      def self.args(argv)
        options = DeletePhotoArgs.new
        ArgParser.parse(argv, into: options)
        options
      end

      def self.valid?(args)
        return false if args.ids.empty?
        return false if args.frame.nil? && args.calendar.nil?

        true
      end

      ArgParser = OptionParser.new do |opts|
        opts.banner = "Usage: #{usage}"

        opts.on("-f", "--frame FRAME", "Frame to delete photos from")
        opts.on("-c", "--calendar CALENDAR", "Calendar to delete photos from")
        opts.on("-i", "--id ID", "Photo ID to delete (from list-photos)")

        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit
        end
      end

      def self.execute(config, args)
        client = Skylight::Client.new(config)

        if args.frame
          client.delete_frame_photos(frame_name: args.frame, photo_ids: args.ids)
        else
          client.delete_calendar_photos(calendar_name: args.calendar, photo_ids: args.ids)
        end

        args.ids.each { |id| puts "Deleted #{id}" }
      end
    end
  end
end
