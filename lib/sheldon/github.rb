require 'sinatra/base'
require 'octokit'
require './lib/sheldon/github_event'

module Sheldon
  class Github < Sinatra::Base

    class << self
      def github
        @github ||= Octokit::Client.new access_token: ENV['GITHUB_ACCESS_TOKEN']
      end
    end

    post '/pull_request', agent: /^Github-Hookshot\/.+/ do
      event = GithubEvent.parse(request)
      return 202 if event.ping?
      204
    end

  end
end
