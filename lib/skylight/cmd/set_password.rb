# frozen_string_literal: true

module Skylight
  module Cmd
    module SetPassword
      def self.command
        "set-password"
      end

      def self.help
        "Set the password for the Skylight Frame"
      end

      def self.usage
        "#{command} [PASSWORD]"
      end

      def self.args(argv)
        argv.shift
      end

      def self.valid?(args)
        args
      end

      def self.execute(config, password)
        Skylight::Config.set_auth_string(password)
      end
    end
  end
end
