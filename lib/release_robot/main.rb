require 'uri'
require 'cgi'

module ReleaseRobot
  class Main
    ORG_NAME = 'MammothHR'.freeze
    MINOR_VERSION_TAG = /^v?\d+.\d+.0$/
    PULL_REQUEST_NUMBER = /Merge pull request #(...)/

    attr_accessor :since_minor_version

    def initialize(options)
      @since_minor_version = options.minor
    end

    def start
      repos.each do |repo|
        next unless repo.owner.login == ORG_NAME

        repo_name = repo.full_name

        print "Fetching issues for #{repo_name}"

        tags = client.tags(repo_name)
        minor_tag = get_latest_minor_tag(tags)
        latest_tag = tags.first
        if since_minor_version
          since_tag = minor_tag
        else
          since_tag = latest_tag
        end

        if since_tag.nil?
          print " - no tags found, skipping\n"
          next
        else
          print " since version #{since_tag.name}\n"
        end
        merged_prs = get_merged_prs_since_tag(repo_name, since_tag)
        repo_details = {
          merged: merged_prs,
          latest_any_version: latest_tag.name,
        }

        # New repos with no minor tags yet
        repo_details.merge(latest_minor_version: minor_tag.name) if minor_tag
        pull_requests << [repo_name, repo_details]
      end

      return pull_requests
    end

    def client
      @client ||= Octokit::Client.new(
        login: ENV['GITHUB_USERNAME'],
        password: ENV['GITHUB_PASSWORD'],
        # auto_paginate: true
      )
    rescue => ex
      puts "Failed: #{ex}"
      puts '(Do you have the right Github username and password stored in'
      puts 'GITHUB_USERNAME and GITHUB_PASSWORD?)'
    end

    def repos
      @repos ||= fetch_repos
    end

    def fetch_repos
      repos = client.org_repos(ORG_NAME)
      last_page_uri = URI.parse(client.last_response.rels[:last].href)

      # @TODO: Does this break if there is only one page?
      total_pages = CGI.parse(last_page_uri.query)['page'].first.to_i

      return repos if total_pages < 2

      2.upto(total_pages) do |page|
        repos << client.org_repos(ORG_NAME, page: page)
      end

      repos.flatten.
        sort { |a, b| a.name <=> b.name }.  # alphabetical
        select { |repo| !repo.fork }        # no forks
    end

    def pull_requests
      @pull_requests ||= []
    end

    def get_latest_minor_tag(tags)
      tags.detect{ |tag| tag.name =~ MINOR_VERSION_TAG }
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
