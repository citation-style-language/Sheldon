require 'sinatra/base'
require 'octokit'

require './lib/sheldon/github_helper'

module Sheldon
  class Github < Sinatra::Base

    helpers GithubHelper

    set(:github, Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN']))

    set(:hookshot) { |exp| condition { exp == hookshot? } }

    post '/pull_request', hookshot: true do
      return 202 if ping?

      204
    end

  end
end
