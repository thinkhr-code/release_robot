# release_robot

## Installation

This is just a ruby script, so it doesn't require any installation. It does, however, rely on the octokit gem, so you will need to install that:
```bash
gem install octokit
```
(Verified working with octokit v4.6.2.)

## Usage

This requires your Github username and password to authenticate. They are accessed via the `GITHUB_USERNAME` and `GITHUB_PASSWORD` envars. Once those are stored:

```bash
$ ruby release_prep_robot.rb
```
## What it does

Currently, this gem will scan all repositories in the `MammothHR` Github account, collect any Pull Requests that are labeled with "Ready for Thursday Release" or "Ready for Immediate Release," change the base branch to `weekly-release`, determine the build status from Travis, parse any Podio URLs from the Pull Request body, and print out two summaries:
  1. A verbose summary for posting to #releases channel, which shows the PR title, URL, Podio URL(s) if any, and the build status.
  2. A terse summary with today's date and a bulleted list of PR titles and the repo to which they belong.

## Next steps to automate

- tag repos with the correct tag
  - For the most part, for Thursday releases, this will be the next minor version (i.e. if the last tag was v2.13.2, then next is v2.13.3).
  - For hrsc and hrsc-ember, their tags should always be in sync
- merge PRs with green builds (perhaps a separate script)
  - delete branches after merge
- check if there's a staging branch for merged branches and either
  - include that in the notes, or
  - auto teardown
- mark Podio tasks as Complete after deploy (perhaps a separate script)
- skip CI for all but the last merge to `weekly-release`
  - Can be done by adding 'skip ci' to the merge commit (in th web interface, this can be done when “Confirm Merge” comes up; unsure about API)
- figure out a standard way to define pre- or post-deploy steps so those can be included in the release prep somehow

*"Nice to have" Slack integrations:*
These would require setting up a slack bot server to receive Github webhooks
- Post to #code-review-requests when the label "Needs Code Review" is added (https://developer.github.com/v3/activity/events/types/#labelevent)
- Approved PR adds the :white_check_mark: reaction to the link posted in #code-review-requests (https://developer.github.com/v3/activity/events/types/#pullrequestreviewevent)
- Merged PR automatically adds the :merge: reaction to the link posted in #code-review-requests (https://developer.github.com/v3/activity/events/types/#pullrequestevent)