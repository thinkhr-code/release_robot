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
          podio_urls(repo_name, pr).each { |url| puts url }
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

    def podio_urls(repo_name, pr)
      pr.body.scan PODIO_URL_REGEX
    end
  end
end
