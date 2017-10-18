module ReleaseRobot
  class Printer
    PODIO_URL_REGEX = /https:\/\/podio.com\/hranswerlink-8ee92nawfl\/issue-tracker\/apps\/product-feedback\/items\/\d+/
    PRE_DEPLOY_REGEX = /PRE DEPLOY TASKS(.*?)## /m

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

      puts "For today's release:\n\n"

      pull_requests.each do |(full_repo_name, details_hsh)|
        owner_name_length = ReleaseRobot::Main::REPO_OWNER.size + 1
        repo_name = full_repo_name[owner_name_length..-1]
        latest_minor_version = details_hsh[:latest_minor_version]
        latest_any_version = details_hsh[:latest_any_version]
        prs = details_hsh[:merged]

        if prs.any?
          puts repo_name.upcase
          print 'Latest Version: '
          puts latest_any_version if latest_any_version
          print 'Latest Minor Version: '
          puts latest_minor_version if latest_minor_version
          puts
        end

        prs.each do |pr|
          puts pr.title
          collect_pre_deploy_tasks(repo_name, pr)
          collect_podio_urls(pr)
        end

        if pre_deploy_tasks[repo_name].flatten.any?
          puts
          puts "Pre deploy tasks for #{repo_name}:"
          pre_deploy_tasks[repo_name].each { |task| puts task }
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

    def collect_pre_deploy_tasks(repo_name, pr)
      enclosed = pr.body[PRE_DEPLOY_REGEX, 1]

      return if enclosed.nil?

      pre_deploy_tasks[repo_name] = [] if pre_deploy_tasks[repo_name].nil?
      pre_deploy_tasks[repo_name] << enclosed.split("\r\n").map do |line|
        next if line.size < 6 # Not blank or blank with checkbox

        line.gsub('- [ ] ', '').gsub("\r\n", '')
      end
    end

    def pre_deploy_tasks
      @pre_deploy_tasks ||= {}
    end

    def collect_podio_urls(pr)
      podio_urls << pr.body.scan(PODIO_URL_REGEX)
    end

    def podio_urls
      @podio_urls ||= []
    end
  end
end
