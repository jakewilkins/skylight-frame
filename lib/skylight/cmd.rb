# frozen_string_literal: true

require "pathname"

require_relative "../skylight"

cmd_dir = Pathname.new(__FILE__).dirname.join("cmd")

Dir[cmd_dir.join("*.rb")].each do |file|
  require file
end

module Skylight
  module Cmd
    class << self
      def run
        this_command, args = validate_command
        run_command(this_command, args)
      end

      def debug(msg)
        return unless debug?
        $stderr.puts msg
      end

      private

      def validate_command
        if ARGV.empty?
          puts "No command specified. Please specify a command to run."
          puts "Valid commands are: #{commands.join(", ")}"
          exit 1
        end

        command = ARGV.shift
        if !commands.include?(command)
          puts "Unknown command: #{command}"
          puts "Valid commands are: #{commands.join(", ")}"
          exit 1
        end

        this_command = command_class(command)
        args = this_command.args(ARGV)

        if !this_command.valid?(args)
          puts "Invalid arguments for command: #{command}"
          puts "Arguments: #{args.inspect}"
          puts "Usage: #{this_command.usage}"
          exit 1
        end

        [this_command, args]
      end

      def run_command(command, args)
        debug "Running command: #{command.command}"
        debug "Arguments: #{args.inspect}"
        command.execute(Skylight::Config.load, *args)
      rescue StandardError => e
        $stderr.puts "Error running command: #{command.command}"

        debug "#{e.class} - #{e.message}"
        debug e.backtrace.first
        exit 1
      end

      def command_class(command)
        Cmd.const_get(constants[commands.index(command)])
      end

      def debug?
        ENV["DEBUG"]
      end

      def commands
        Cmd.constants.map do |const|
          Cmd.const_get(const).command
        end
      end
    end
  end
end
