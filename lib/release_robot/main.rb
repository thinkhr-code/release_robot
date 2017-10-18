module ReleaseRobot
  class Main
    REPO_OWNER = 'MammothHR'.freeze
    VERSION_TAG = /^v?\d+.\d+.\d+$/
    PULL_REQUEST_NUMBER = /Merge pull request #(...)/

    def start
      repos.each do |repo|
        next unless repo.owner.login == REPO_OWNER

        repo_name = repo.full_name

        puts "Fetching issues for #{repo_name}"

        tag = get_latest_tag(repo_name)

        next if tag.nil?

        merged_prs = get_merged_prs_since_tag(repo_name, tag)
        pull_requests << { repo_name => merged_prs }
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
      @repos ||= client.repos(owner: REPO_OWNER)
    end

    def pull_requests
      @pull_requests ||= []
    end

    def get_latest_tag(repo_name)
      client.tags(repo_name).first
    end

    def get_merged_prs_since_tag(repo_name, tag)
      base_sha = tag.commit.sha
      head_sha = client.commits(repo_name, per_page: 1).first.sha
      compare_commits = client.compare(repo_name, base_sha, head_sha).commits

      compare_commits.map do |c|
        matches = c.commit.message.match(PULL_REQUEST_NUMBER)
        unless matches.nil?
          pr_number = matches.captures.first
          puts "- Fetching #{repo_name} pull request ##{pr_number}"
          client.pull_request(repo_name, pr_number)
        end
      end.flatten.compact
    end
  end
end
