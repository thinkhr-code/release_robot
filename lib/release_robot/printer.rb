module ReleaseRobot
  class Printer
    attr_accessor :pull_requests

    def initialize(pull_requests)
      @pull_requests = pull_requests
    end

    def print_all
      print_prep_list
      print_deploy_list
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
  end
end
