module ReleaseRobot
  class Printer
    PODIO_URL_REGEX = /https:\/\/podio.com\/hranswerlink-8ee92nawfl\/issue-tracker\/apps\/product-feedback\/items\/\d+/
    PRE_DEPLOY_REGEX = /PRE DEPLOY TASKS(.*?)## /m
    POST_DEPLOY_REGEX = /\bPOST DEPLOY TASKS.*/m

    attr_accessor :pull_requests, :client

    def initialize(pull_requests, client)
      @pull_requests = pull_requests
      @client = client
    end

    def print_all
      print_prep_list
    end

    def print_prep_list
      print_title 'Prep list for #releases'

      puts "For today's release:\n"

      pull_requests.each do |(full_repo_name, details_hsh)|
        owner_name_length = ReleaseRobot::Main::REPO_OWNER.size + 1
        repo_name = full_repo_name[owner_name_length..-1]
        latest_minor_version = details_hsh[:latest_minor_version]
        latest_any_version = details_hsh[:latest_any_version]
        prs = details_hsh[:merged]

        if prs.any?
          puts
          puts repo_name.upcase
          print 'Latest Version: '
          puts latest_any_version if latest_any_version
          print 'Latest Minor Version: '
          puts latest_minor_version if latest_minor_version
          puts
        end

        deploy_tasks[repo_name] ||= {}

        puts "\nTo Be Released: " if prs.any?
        prs.each do |pr|
          puts pr.title
          collect_tasks(repo_name, pr)
          collect_podio_urls(pr)
        end

        if deploy_tasks[repo_name].any?
          deploy_tasks[repo_name].each_pair do |type, tasks|
            # Regex parsing isn't perfect...
            valid_tasks = tasks.flatten.reject { |t| t.nil? || t.empty? }
            if valid_tasks.any?
              puts
              puts "#{type.capitalize} deploy tasks for #{repo_name}:"
              valid_tasks.each { |task| puts task }
            end
          end
        end
      end

      if podio_urls.flatten.any?
        puts
        puts 'Podio issues to close:'
        podio_urls.each { |url| puts url }
      end
    end

    def print_title(title)
      puts
      puts '-' * 50
      puts title
      puts '-' * 50
      puts
    end

    def collect_tasks(repo_name, pr)
      deploy_tasks[repo_name] ||= {}

      # @TODO: Fix this spaghetti - change PR template so it is easier to parse
      %w(pre post).each do |type|
        if type == 'pre'
          regex = PRE_DEPLOY_REGEX
          enclosed = pr.body[regex, 1]
          next if enclosed.nil?
          lines = enclosed.split("\r\n")
        elsif type == 'post'
          regex = POST_DEPLOY_REGEX
          enclosed = pr.body.scan(regex)
          next if enclosed.empty?
          lines = enclosed.first.split("\r\n")
        end

        next if lines.empty?

        deploy_tasks[repo_name][type] ||= []
        deploy_tasks[repo_name][type] << lines.map do |line|
          next if line == 'POST DEPLOY TASKS'
          next if line.size < 6 # Not blank or blank with checkbox

          line.gsub('- [ ] ', '').gsub("\r\n", '')
        end
      end
    end

    def deploy_tasks
      @deploy_tasks ||= {}
    end

    def collect_podio_urls(pr)
      podio_urls << pr.body.scan(PODIO_URL_REGEX)
    end

    def podio_urls
      @podio_urls ||= []
    end
  end
end
