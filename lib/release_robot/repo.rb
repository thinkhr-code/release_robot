module ReleaseRobot
  class Repo
    ORG_NAME = 'MammothHR'.freeze
    MINOR_VERSION_TAG = /^v?\d+.\d+.0$/
    PULL_REQUEST_NUMBER = /Merge pull request #(...)/

    attr_accessor :client, :github_repo, :since_minor_version

    class << self
      attr_accessor :repos

      def import(client, since_minor_version)
        @repos = fetch_repos(client).map do |repo|
          Repo.new(client, repo, since_minor_version)
        end.compact
      end

      def all
        @repos.flatten
      end

      # @TODO: Clean up this rat's nest - it is necessary because of pagination
      # and because octokit's `auto_paginate` does not seem to behave properly
      def fetch_repos(client)
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
    end

    def initialize(client, github_repo, since_minor_version)
      @client = client
      @github_repo = github_repo
      @since_minor_version = since_minor_version
    end

    def full_name
      github_repo.full_name
    end


    def print_status
      print "Fetching issues for #{full_name}"

      print_version_tag
    end

    def should_skip?
      since_tag.nil?
    end

    def details
      {
        merged: get_merged_prs_since_tag,
        latest_any_version: latest_tag.name,
      }.tap do |hsh|
        # New repos with no minor tags yet
        hsh[:latest_minor_version] = minor_tag.name unless minor_tag.nil?
      end
    end

    private

    def name
      github_repo.name
    end

    def print_version_tag
      if since_tag.nil?
        print " - no tags found, skipping\n"
      else
        print " since version #{since_tag.name}\n"
      end
    end

    def since_tag
      @since_tag ||= since_minor_version ? minor_tag : latest_tag
    end

    def minor_tag
      @minor_tag ||= tags.detect{ |tag| tag.name =~ MINOR_VERSION_TAG }
    end

    def latest_tag
      @latest_tag ||= tags.first
    end

    def tags
      @tags ||= client.tags(full_name)
    end

    def get_merged_prs_since_tag
      compare_commits.map do |c|
        matches = c.commit.message.match(PULL_REQUEST_NUMBER)
        unless matches.nil?
          pr_number = matches.captures.first
          puts "- Fetching #{full_name} pull request ##{pr_number}"
          client.pull_request(full_name, pr_number)
        end
      end.flatten.compact
    end

    def compare_commits
      client.compare(full_name, base_sha, head_sha).commits
    end

    def base_sha
      since_tag.commit.sha
    end

    def head_sha
      client.commits(full_name, per_page: 1).first.sha
    end
  end
end
