require 'sinatra/base'
require 'sinatra/config_file'
require 'octokit'
require 'logger'

require './lib/sheldon/github_helper'
require './lib/sheldon/template'

module Sheldon
  class Bot < Sinatra::Base

    configure :production do
      set :logging, Logger::INFO
      enable :protection
    end

    configure :development do
      set :logging, Logger::DEBUG
    end

    configure :development, :test do
      enable :raise_errors
      disable :show_exceptions
    end

    set :root, File.expand_path('../../..', __FILE__)

    register Sinatra::ConfigFile
    config_file 'config/github.yml'

    helpers GithubHelper

    set(:github, Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN']))

    post '/pull_request' do
      return 400 unless hookshot?

      logger.info "GitHub hookshot #{github_event.inspect} received"

      return 202 if ping?
      return 400 unless pull_request?

      options = settings.pull_request[pull_request_action]
      return 202 if options.nil?

      template = Template.load options['template']

      comment = github.add_comment(
        repository['full_name'],
        pull_request['number'],
        template.render(pull_request))

      #[201, nil, { location: comment.url }]
      201
    end


    get '/status' do
      'OK'
    end

    get '/version' do
      VERSION
    end

    not_found do
      logger.info "Not found: #{request.url}"
      'Not found. Bazinga!'
    end

    error do
      logger.error "Error: #{env['sinatra.error'].message}"
      "Bazinga! #{env['sinatra.error'].message}"
    end

    # Start Sheldon if this file was executed directly
    run! if app_file == $0
  end
end
