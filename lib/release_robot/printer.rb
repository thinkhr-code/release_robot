module ReleaseRobot
  class Printer
    PODIO_URL_REGEX = /https:\/\/podio.com\/hranswerlink-8ee92nawfl\/issue-tracker\/apps\/product-feedback\/items\/\d+/

    attr_accessor :pull_requests, :client

    def initialize(pull_requests, client)
      @pull_requests = pull_requests
      @client = client
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

    def podio_urls(repo_name, issue)
      pr = client.pull_request(repo_name, issue.number)
      pr.body.scan PODIO_URL_REGEX
    end
  end
end
