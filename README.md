# Sheldon

Sheldon is used to provide test feedback on styles/locales PRs. It
assumes a few things about the environment it's ran in, most of
which will automatically be set up correctly when ran on Travis
(which is where it will usually run).

## Environment variables

* `GITHUB_TOKEN` must be set manually on each travis project that uses it. Sheldon will post comments under the account tied to this token. Recommended to use a dedicated bot account. The account that this token is tied to must have comment access on the repo on which the Travis tests run.
* `TRAVIS_PULL_REQUEST` is the number of the pull request/issue. Set by Travis.
* `TRAVIS_COMMIT_RANGE` is the range of commits included in the PR. Set by Travis.
* `TRAVIS_REPO_SLUG` is the repo being tested. Set by Travis.
* `TRAVIS_BUILD_ID` is the internal Travis build ID. Not the same as the build number. Set by Travis.

example `.env` for local testing:

```
GITHUB_TOKEN=...
TRAVIS_PULL_REQUEST=1
TRAVIS_COMMIT_RANGE=master
TRAVIS_REPO_SLUG=clone/styles
TRAVIS_BUILD_ID=1
```

## Expected files in the repo being tested.

* `spec/sheldon/travis.json` (optional). Generated by rspec; when present, Sheldon will look for errors in this file. When errors are found, Sheldon will post `build_failed.md.erb` (see below) and quit.
* `spec/sheldon/pull_request_opened.md.erb`: the welcome message when a new PR is opened. Even though this is an ERB template, no variables are currently passed to it.
* `spec/sheldon/build_passed.md.erb`: the message posted when tests pass. Gets variable `build_url` to link back to the Travis report. For styles, also gets the variable `details`, which contains a rendering of the modified/added styles.
* `spec/sheldon/build_failed.md.erb`: the message posted when tests fail. Gets variable `build_url` to link back to the Travis report.

# Updating Sheldon

After making changes to Sheldon,

* commit your changes
* run `rake bump`
* run `git push`
* run `bundle update` in the `styles` and `locales` repos
