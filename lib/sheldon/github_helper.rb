require 'json'

module Sheldon
  module GithubHelper

    def hookshot?
      return false unless request.user_agent =~ /^Github-Hookshot\/\w+/
      return false unless request.media_type == 'application/json'
      true
    end

    def github_event
      request.env['X_GITHUB_EVENT']
    end

    def github_payload
      @github_payload ||= JSON.parse request.body.read
    end

    def ping?
      github_event == 'ping'
    end

    def pull_request?
      github_event == 'pull_request'
    end

    def pull_request_action
      github_payload['action']
    end

    def pull_request
      github_payload['pull_request']
    end

    def repository
      github_payload['repository']
    end

    def github
      settings.github
    end

  end
end
