require 'optparse'
require 'optparse/date'
require 'ostruct'
require 'json'
require 'octokit'
require 'highline/import'
require 'release_robot/main'
require 'release_robot/printer'
require 'pry'

module ReleaseRobot
  class << self
    def run(args)
      options = ReleaseRobot.parse(args)

      create_settings_file_if_nonexistent

      fetch_envars_from_config

      missing_envars = get_missing_envars

      write_missing_envars(missing_envars) if missing_envars.any?

      robot = ReleaseRobot::Main.new(options)
      pull_requests = robot.start
      client = robot.client

      ReleaseRobot::Printer.new(pull_requests, client).print_all
    end

    def parse(args)
      options = OpenStruct.new

      opt_parser = OptionParser.new do |opts|
        opts.separator ''
        opts.banner = 'Usage: release_robot [options]'

        opts.separator ''
        opts.separator 'Common options:'

        opts.separator ''
        opts.on('-m', '--minor-version', 'Get PRs since the last *minor* version (default is to get them from last *patch* version).') do |minor|
          options.minor = minor
        end

        opts.on_tail('-h', '--help', 'Show this message') do
          puts opts
          exit
        end

        opts.on_tail('-v', '--version', 'Show version') do
          puts ReleaseRobot::VERSION
          exit
        end
      end

      opt_parser.parse!(args)
      options
    end

    def get_missing_envars
      missing_envars = {}

      ReleaseRobot.envars.each do |key|
        next if ENV[key]
        missing_envars[key] = get_envar(key)
      end

      return missing_envars
    end

    def get_envar(key)
      if key =~ /GITHUB_PASSWORD/
        env_value = ask("Enter your #{key}: ") { |q| q.echo = "*" }
      else
        print "Enter your #{key}: "
        env_value = gets.chomp
      end
      env_value.strip! unless should_not_strip?(key)
      if env_value.length == 0
        puts 'Invalid input. This is a required field.'
        exit
      end
      env_value
    end

    def should_not_strip?(key)
      false
    end

    def fetch_envars_from_config
      return unless envars = YAML.load_file(settings_file_path)
      envars.each_pair do |key, value|
        value.strip! unless should_not_strip?(key)
        ENV[key.upcase] = value
      end
    end

    def write_missing_envars(missing_envars={})
      puts "\nTo avoid entering setup information each time, the following configuration has been stored in `#{settings_file_path}`:"
      missing_envars.each_pair do |key, value|
        if key =~ /password|token/i
          puts "\t#{key}=[FILTERED]"
        else
          puts "\t#{key}=#{value}"
        end

        data = YAML.load_file(settings_file_path) || {}
        ENV[key.upcase] = data[key.downcase] = value
        File.open(settings_file_path, 'w') { |f| YAML.dump(data, f) }
      end
    end

    def create_settings_file_if_nonexistent
      File.new(settings_file_path, "w+") unless File.file?(settings_file_path)
    end

    def settings_file_path
      File.join(ENV['HOME'], '.release_robot_settings.yml')
    end

    def root
      File.dirname __dir__
    end

    def envars
      envars_help.keys
    end

    def envars_help
      {
        'GITHUB_USERNAME' =>
          "Your username for github.com\n\n",

        'GITHUB_PASSWORD' =>
          "Your password for github.com\n\n",
      }
    end
  end
end
