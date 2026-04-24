# frozen_string_literal: true

module Skylight
  module Cmd
    module ListCalendars
      def self.command
        "list-calendars"
      end

      def self.help
        "List the Calendars for the Skylight Account"
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
        client.list_calendars.each do |calendar|
          puts " - #{calendar.name}"
        end
      end
    end
  end
end
