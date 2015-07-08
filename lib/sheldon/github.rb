require 'sinatra/base'
require 'sinatra/config_file'
require 'octokit'

require './lib/sheldon/github_helper'

module Sheldon
  class Github < Sinatra::Base
    enable :logging
    enable :protection

    set :root, File.expand_path('../../..', __FILE__)

    register Sinatra::ConfigFile
    config_file 'config/github.yml'

    helpers GithubHelper

    set(:github, Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN']))
    set(:hookshot) { |exp| condition { exp == hookshot? } }


    post '/pull_request', hookshot: true do
      return 202 if ping?

      return 400 unless pull_request?
      return 202 if pull_request_comment.nil?

      # post comment

      201
    end

  end
end
