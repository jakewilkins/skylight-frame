# frozen_string_literal: true

require "io/console"

module Skylight
  module Cmd
    module Login
      def self.command
        "login"
      end

      def self.help
        "Exchange securely stored credentials for an Access Token"
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
        creds = config.credentials
        email, password = if creds
          Cmd.debug "Using stored credentials for #{creds['email']}"
          [creds["email"], creds["password"]]
        else
          prompt_credentials
        end

        $stderr.print "Logging in..."
        token_data = Skylight::Auth.login(email, password)
        $stderr.puts " done!"

        Skylight::Config::AuthorizationProvider.update(
          "access_token" => token_data["access_token"],
          "refresh_token" => token_data["refresh_token"],
          "expires_in" => token_data["expires_in"],
          "created_at" => token_data["created_at"]
        )

        expires_hours = (token_data["expires_in"].to_i / 3600.0).round(1)
        puts "Logged in successfully. Token expires in #{expires_hours} hours."
      rescue StandardError => e
        $stderr.puts "Login failed: #{e.message}"
        Cmd.debug e.backtrace&.first
        exit 1
      end

      def self.prompt_credentials
        $stderr.print "Email: "
        email = $stdin.gets&.chomp
        $stderr.print "Password: "
        password = $stdin.noecho(&:gets)&.chomp
        $stderr.puts

        raise "Email and password are required" if email.nil? || email.empty? || password.nil? || password.empty?

        [email, password]
      end

      private_class_method :prompt_credentials
    end
  end
end
