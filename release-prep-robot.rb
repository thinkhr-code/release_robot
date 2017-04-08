require 'octokit'

PODIO_URL_REGEX = /https:\/\/podio.com\/hranswerlink-8ee92nawfl\/issue-tracker\/apps\/product-feedback\/items\/\d+/

def labels
  ['Ready for Thursday Release', 'Ready for Immediate Release']
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

    puts "Fetching issues for #{repo.full_name}"

    all_issues = labels.map do |label|
      client.list_issues(repo.full_name, labels: label)
    end.flatten

    collect_pull_requests(repo, all_issues)
  end
end

def collect_pull_requests(repo, all_issues)
  all_issues.each do |issue|
    print "- Determining build status for #{issue.number}"
    pull = client.pull_request(repo.full_name, issue.number)

    # Build status
    status = client.combined_status(repo.full_name, pull.head.sha)

    sort_issue_by_status(issue, status.state, repo.full_name)
  end
end

def method_name

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
