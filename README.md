# release_robot

## Installation

```bash
$ rake install
$ release_robot
```

## Usage

This requires your Github username and password to authenticate and requires that you *do not* have 2-factor auth setup for Github. The gem will prompt you for those credentials on first run and store them in `~/.release_robot_settings.yml`.

## What it does

Currently, this gem will scan all repositories in the `MammothHR` Github account, collect any Pull Requests merged since the last version, parse any Podio URLs, pre deploy tasks, or post deploy tasks from the Pull Request body (provided that repo uses the [standard pull request template](https://github.com/MammothHR/release_robot/blob/master/PULL_REQUEST_TEMPLATE.md)), and print out a summary.

## Next steps to automate

See [ISSUES](https://github.com/MammothHR/release_robot/issues).
