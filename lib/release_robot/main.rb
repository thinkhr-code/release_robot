module ReleaseRobot
  class Main
    attr_accessor :since_minor_version

    def initialize(options)
      @since_minor_version = options.minor
      Repo.import client, since_minor_version
    end

    def start
      repos.each do |repo|
        repo.print_status

        next if repo.should_skip?

        pull_requests << [repo.full_name, repo.details]
      end

      return pull_requests
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
      @repos ||= Repo.all
    end

    def pull_requests
      @pull_requests ||= []
    end
  end
end
