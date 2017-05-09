require 'octokit'

PODIO_URL_REGEX = /https:\/\/podio.com\/hranswerlink-8ee92nawfl\/issue-tracker\/apps\/product-feedback\/items\/\d+/
RELEASE_BASE_BRANCH = 'weekly-release'.freeze
THURSDAY_LABEL = 'Ready for Thursday Release'.freeze
IMMEDIATE_LABEL = 'Ready for Immediate Release'.freeze

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

def run
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
