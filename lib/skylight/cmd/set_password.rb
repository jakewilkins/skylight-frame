# frozen_string_literal: true

module Skylight
  module Cmd
    module SetPassword
      def self.command
        "set-password"
      end

      def self.help
        "Store credentials (email and password) for the Skylight account"
      end

      def self.usage
        "#{command} EMAIL PASSWORD"
      end

      def self.args(argv)
        return nil if argv.length < 2

        { email: argv.shift, password: argv.shift }
      end

      def self.valid?(args)
        args.is_a?(Hash) && args[:email] && args[:password]
      end

      def self.execute(_config, args)
        Skylight::Config::AuthorizationProvider.update(
          "email" => args[:email],
          "password" => args[:password]
        )
        puts "Credentials stored."
      end
    end
  end
end
