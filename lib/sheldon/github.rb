require 'sinatra/base'
require 'sinatra/config_file'
require 'octokit'

require './lib/sheldon/github_helper'
require './lib/sheldon/template'

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


    before '/pull_request', hookshot: true do
      logger.info "GitHub hookshot #{github_event.inspect} received"
    end

    post '/pull_request', hookshot: true do
      return 202 if ping?
      return 400 unless pull_request?

      options = settings.pull_request[pull_request_action]
      return 202 if options.nil?

      template = Template.load options['template']

      comment = github.add_comment(
        repository['full_name'],
        pull_request['number'],
        template.render(pull_request))

      [201, nil, { location: comment.url }]
    end

  end
end
