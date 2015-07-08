module Sheldon
  module GithubHelper

    def hookshot?
      return false unless request.user_agent =~ /^Github-Hookshot\/\w+/
      return false unless request.media_type == 'application/json'
      true
    end

    def github_event
      @github_event ||= request.env['X_GITHUB_EVENT'].to_s.intern
    end

    def ping?
      github_event == :ping
    end

  end
end
