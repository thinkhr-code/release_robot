require 'optparse'
require 'optparse/date'
require 'ostruct'
require 'json'
require 'octokit'

module ReleaseRobot
  class << self

    PODIO_URL_REGEX = /https:\/\/podio.com\/hranswerlink-8ee92nawfl\/issue-tracker\/apps\/product-feedback\/items\/\d+/
    RELEASE_BASE_BRANCH = 'weekly-release'.freeze
    THURSDAY_LABEL = 'Ready for Thursday Release'.freeze
    IMMEDIATE_LABEL = 'Ready for Immediate Release'.freeze

    def run(args)
      options = ReleaseRobot.parse(args)

      create_settings_file_if_nonexistent

      fetch_envars_from_config

      missing_envars = get_missing_envars

      ReleaseRobot.start

      write_missing_envars(missing_envars) if missing_envars.any? && options.save
    end

    def parse(args)
      options = OpenStruct.new
      options.save = false

      opt_parser = OptionParser.new do |opts|
        opts.separator ''
        opts.banner = 'Usage: release_robot [options]'

        opts.separator ''
        opts.separator 'Specific options:'

        opts.separator ''
        opts.on('-s', '--save',
                'Use this flag to save you settings to a file -',
                '`~/.release_robot_settings.yml` - to be used again the next', 'time you invoke the robot.') do |save|
          options.save = save
        end

        opts.separator ''
        opts.separator 'Common options:'

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
      print "Enter your #{key}: "
      env_value = gets.chomp
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

    def start
      repos.each do |repo|
        next unless repo.owner.login == 'MammothHR'

        repo_name = repo.full_name
        puts "Fetching issues for #{repo_name}"

        all_issues = labels.map do |label|
          client.list_issues(repo_name, labels: label)
        end.flatten

        all_issues.each do |issue|
          collect_pull_requests(repo_name, issue)
        end
      end
    end

    def labels
      [THURSDAY_LABEL, IMMEDIATE_LABEL]
    end

    def client
      @client ||= Octokit::Client.new(
        login: ENV['GITHUB_USERNAME'],
        password: ENV['GITHUB_PASSWORD']
      )
    rescue => ex
      puts "Failed: #{ex}"
      puts '(Do you have the right Github username and password stored in'
      puts 'GITHUB_USERNAME and GITHUB_PASSWORD?)'
    end

    def repos
      @repos ||= client.repos(owner: 'MammothHR')
    end

    def pull_requests
      @pull_requests ||= {
        'success' => [],
        'pending' => [],
        'failure' => []
      }
    end

    def collect_pull_requests(repo_name, issue)
      print "- Determining build status for #{issue.number}"
      pull_request = client.pull_request(repo_name, issue.number)

      # Build status
      status = client.combined_status(repo_name, pull_request.head.sha)

      change_base(repo_name, pull_request)

      sort_issue_by_status(issue, status.state, repo_name)
    end

    def change_base(repo_name, pull_request)
      client.update_pull_request(
        repo_name,
        pull_request.number,
        nil,
        nil,
        base: RELEASE_BASE_BRANCH
      )
    rescue Octokit::UnprocessableEntity => ex
      puts "Error occurred when attempting to change base branch to #{RELEASE_BASE_BRANCH}:"
      puts ex.message
    end

    def sort_issue_by_status(issue, status, repo_name)
      case status
      when 'success' then pull_requests['success'] << [repo_name, issue]
      when 'pending' then pull_requests['pending'] << [repo_name, issue]
      when 'failure' then pull_requests['failure'] << [repo_name, issue]
      end

      print " -- #{status}\n"
    end

    def podio_urls(repo_name, issue)
      pr = client.pull_request(repo_name, issue.number)
      pr.body.scan PODIO_URL_REGEX
    end

    def print_prep_list
      print_title 'Prep list for #releases'

      puts "For today's release:\n\n"

      pull_requests.each_pair do |status, issues|
        issues.each do |(repo_name, issue)|
          puts issue.title
          puts issue.html_url
          podio_urls(repo_name, issue).each { |url| puts url }
          puts "*Build #{status}*"
          puts
        end
      end
    end

    def print_deploy_list
      print_title 'List for #deploys'

      puts Date.today.strftime('%D')

      pull_requests.each_pair do |_, issues|
        issues.each do |(repo_name, issue)|
          slug = repo_name.gsub('MammothHR/', '')

          puts "(#{slug}) #{issue.title}"
        end
      end
    end

    def print_title(title)
      puts
      puts '-' * 50
      puts title
      puts '-' * 50
      puts
    end

    run

    print_prep_list

    print_deploy_list


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
